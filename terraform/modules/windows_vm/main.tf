
# ============================================================
# Windows VM (using DEFAULT AWS Windows AMI)
# Launch a plain Windows Server 2022 VM

# ── Find latest Windows Server 2022 AMI (AWS default) ──
data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ── Security Group ──
resource "aws_security_group" "windows_sg" {
  name        = "${var.project_name}-windows-sg"
  description = "Security group for Windows VM"
  vpc_id      = var.vpc_id

  # RDP access
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "RDP access"
  }

  # WinRM HTTP (for Ansible)
  ingress {
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "WinRM HTTP"
  }

  # WinRM HTTPS (for Ansible)
  ingress {
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "WinRM HTTPS"
  }

  # All outbound (for downloading installers)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = {
    Name = "${var.project_name}-windows-sg"
  }
}

# ── Windows VM ──
resource "aws_instance" "windows" {
  ami                    = data.aws_ami.windows.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.windows_sg.id]

  # Enable public IP
  associate_public_ip_address = true

  # Root volume (Windows needs at least 30 GB)
  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  # UserData: Enable WinRM for Ansible + Set Admin password
  user_data = <<-EOF
  <powershell>
  # 1. Set password
  net user Administrator "${var.windows_password}" /active:yes

  # 2. Configure WinRM (CRITICAL — without this, Ansible can't connect)
  winrm quickconfig -q
  winrm set winrm/config '@{MaxTimeoutms="1800000"}'
  winrm set winrm/config/service '@{AllowUnencrypted="true"}'
  winrm set winrm/config/service/auth '@{Basic="true"}'
  winrm set winrm/config/client/auth '@{Basic="true"}'

  # 3. Open firewall
  netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in action=allow protocol=TCP localport=5985

  # Increase WinRM Shell Limits 
  Set-Item WSMan:\localhost\Shell\MaxShellsPerUser -Value 50
  Set-Item WSMan:\localhost\Shell\MaxConcurrentUsers -Value 20
  Set-Item WSMan:\localhost\Shell\MaxProcessesPerShell -Value 25
  Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 1024

  # Increase Timeout to prevent expired shells ──
  Set-Item WSMan:\localhost\Shell\IdleTimeout -Value 7200000
  # 7200000ms = 2 hours

  # Restart WinRM
  Restart-Service WinRM -Force
  </powershell>
EOF

  tags = {
    Name        = "${var.project_name}-windows-vm"
    Environment = var.environment
    ManagedBy   = "terraform"
    auto-delete = "yes"
  }
}


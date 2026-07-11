output "instance_public_ip" {
  description = "IP publica del servidor web"
  value       = aws_instance.web.public_ip
}
output "instance_public_ip" {
  description = "IP publica del servidor web"
  value       = aws_instance.web.public_ip
}
output "bucket_name" {
  description = "Nombre del bucket S3"
  value       = aws_s3_bucket.assets.id
}
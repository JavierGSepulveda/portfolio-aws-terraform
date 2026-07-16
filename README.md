Portafolio: Infraestructura basica en AWS, definida con Terraform. Se apunto a que ningun recuerso fuera creado con la consola de aws
Que incluye:
VPC personalizada con subred pública y subred privada
Instancia EC2 (Amazon Linux 2023) sirviendo una página web con nginx
Security Group con acceso restringido (HTTP público, SSH solo desde una IP específica)
Bucket S3 privado para assets estáticos, con bloqueo explícito de acceso público
Internet Gateway y tabla de rutas configurados manualmente (sin recursos "default" de AWS)

Arquitectura
                         Internet
                            │
                    [Internet Gateway]
                            │
                    ┌───────┴────────┐
                    │   VPC (10.0.0.0/16)
                    │
                    │  ┌──────────────────────┐
                    │  │ Subred pública         │
                    │  │ 10.0.1.0/24            │
                    │  │                        │
                    │  │  [EC2 + nginx]         │
                    │  │  Security Group:       │
                    │  │   - HTTP (80) abierto  │
                    │  │   - SSH (22) solo mi IP│
                    │  └──────────────────────┘
                    │
                    │  ┌──────────────────────┐
                    │  │ Subred privada         │
                    │  │ 10.0.2.0/24            │
                    │  │ (sin recursos,         │
                    │  │  sin ruta a internet)  │
                    │  └──────────────────────┘
                    └────────────────┘

        [S3 bucket privado] — servicio separado, fuera de la VPC

VPC con subred pública y privada

Se separaron las subredes para aplicar seguridad en capas: la subred privada no tiene ruta a internet, por lo que cualquier recurso ahí sería físicamente inalcanzable desde afuera, no solo bloqueado por una regla. En este proyecto la subred privada queda vacía (es un proyecto de portafolio), pero el patrón queda listo para escalar — por ejemplo, agregar una base de datos ahí en el futuro.

Sin NAT Gateway

Un NAT Gateway permitiría que recursos en la subred privada salieran a internet sin ser alcanzables desde afuera. Se decidió no incluirlo porque: (1) no hay ningún recurso en la subred privada que lo necesite en este proyecto, y (2) tiene un costo fijo por hora (~USD $33/mes) incluso estando inactivo, no cubierto por ningún free tier. Es una decisión consciente de costo-beneficio.

Security Groups en vez de NACLs

Se usaron Security Groups (firewall a nivel de instancia, con estado/stateful) como control principal de tráfico. Las NACLs (firewall a nivel de subred, sin estado) se dejaron en su configuración default de la VPC, porque para el alcance de este proyecto el control por instancia es suficiente y es el enfoque más común en arquitecturas reales.

Puerto 22 (SSH) restringido a una IP específica

La regla de entrada SSH usa /32 (exactamente una IP, la del desarrollador) en vez de 0.0.0.0/0. Es la diferencia concreta entre un Security Group "bien hecho" y uno "todo abierto".

Sin HTTPS (puerto 443)

No se abrió el puerto 443 porque HTTPS requiere un certificado SSL/TLS válido, y obtener uno gratis (ej. Let's Encrypt) exige un dominio propio apuntando al servidor — comprar un dominio quedó fuera del alcance de este proyecto. Abrir el puerto sin certificado habría sido una regla "decorativa" sin función real.

Tipo de instancia: t3.micro

Se usó t3.micro en lugar del clásico t2.micro porque la cuenta de AWS utilizada está bajo el modelo "Free Plan" (cuentas creadas desde julio de 2025), cuyo listado de tipos elegibles para el nivel gratuito no incluye t2.micro.

Bucket S3 con bloqueo de acceso público explícito

Aunque AWS bloquea el acceso público por defecto en buckets nuevos desde 2023, se declaró explícitamente el recurso aws_s3_bucket_public_access_block como una segunda capa de protección — si en el futuro se agregara una política de bucket sin darse cuenta de que rompe la privacidad, este bloque la neutraliza activamente.

Sin backend remoto para el estado de Terraform

El archivo terraform.tfstate se maneja localmente (excluido de git vía .gitignore). En un entorno de equipo, este estado se guardaría en un backend remoto compartido (ej. un bucket S3 dedicado) para que varias personas puedan trabajar sobre la misma infraestructura sin conflictos. Se dejó fuera de alcance porque este proyecto es de un solo desarrollador trabajando desde una sola máquina.

Cuenta AWS: Free Plan

Todo el proyecto se diseñó para operar dentro de un Free Plan de AWS (créditos gratuitos, sin riesgo de cobro real). Disciplina seguida durante el desarrollo: cada sesión de trabajo terminó con terraform destroy, para no dejar recursos corriendo entre sesiones.

Cómo ejecutar este proyecto

Prerrequisitos


Cuenta de AWS con credenciales configuradas (aws configure)
Terraform instalado
Un usuario IAM con permisos suficientes (no usar el usuario root)

Pasos
git clone https://github.com/JavierGSepulveda/portfolio-aws-terraform.git
cd portfolio-aws-terraform
terraform init
terraform plan
terraform apply


Al terminar el apply, Terraform muestra en los outputs la IP pública de la instancia y el nombre del bucket S3. Prueba que la web responde con:
Invoke-WebRequest -Uri "http://<instance_public_ip>"

Importante: destruir al terminar

Este proyecto no mantiene infraestructura corriendo de forma permanente — es una decisión deliberada para evitar cualquier costo. Después de verificar que todo funciona:
terraform destroy

Si el bucket S3 ya tiene objetos subidos, puede ser necesario agregar force_destroy = true al recurso aws_s3_bucket para poder eliminarlo junto con su contenido.

Estructura del proyecto:
portfolio-aws-terraform/
├── providers.tf      # Provider de AWS y random, versiones fijadas
├── variables.tf       # (reservado para valores configurables)
├── main.tf             # Todos los recursos: VPC, subredes, EC2, SG, S3, etc.
├── outputs.tf          # IP pública de la instancia, nombre del bucket
├── user_data.sh         # Script de arranque de la instancia (instala nginx)
├── assets/hello.txt      # Archivo de prueba subido al bucket S3
├── .gitignore
└── README.md



Aprendizajes del proceso (troubleshooting real)

Algunos errores reales resueltos durante el desarrollo, documentados porque el proceso de depuración es tan valioso como el resultado final:


Shebang mal formado en user_data.sh (# !#/bin/bash en vez de #!/bin/bash): causó que el script de instalación de nginx no se ejecutara en absoluto, sin generar ningún error visible en terraform apply — la instancia se marcaba como saludable pero nginx nunca llegaba a instalarse. Se diagnosticó revisando /var/log/cloud-init-output.log por SSH.
security_groups vs. vpc_security_group_ids: el primero es para la VPC "default" de la cuenta y espera nombres; el segundo es el correcto para una VPC personalizada y espera IDs.
Tipo de instancia no elegible para free tier: t2.micro no está disponible en cuentas bajo el modelo "Free Plan" (post julio 2025); se resolvió usando t3.micro.


Posibles mejoras futuras (fuera de alcance de este proyecto)


Distribuir subredes en múltiples Availability Zones para alta disponibilidad real
Backend remoto de Terraform (S3 + DynamoDB para locking de estado)
HTTPS con dominio propio y certificado de Let's Encrypt
Pipeline de CI/CD para automatizar terraform plan en cada pull request


Autor

Javier Gary — proyecto de portafolio, construido como parte de un proceso de aprendizaje autónomo en infraestructura como código.
#!/bin/bash

dnf install -y docker git
git clone https://github.com/benaitcheson/fire-runway.git
cd fire-runway/
systemctl enable docker
systemctl start docker
docker build -t fire-runway .
docker run -d -p 80:3000 \
  -e SECRET_KEY_BASE=${secret_key_base} \
  -e DATABASE_URL=${database_url} \
  fire-runway

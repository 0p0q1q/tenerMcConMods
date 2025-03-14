#!/bin/bash

PROJECT_DIR="minecraft-docker-playit-1.20.1"
mkdir -p "$PROJECT_DIR/trollserver"

# docker stop $(docker ps -aq) && docker rm -vf $(docker ps -aq) && docker rmi -f $(docker images -q) && docker volume prune -f && docker network prune -f && docker system prune -af

cat <<EOF > "$PROJECT_DIR/Dockerfile"
FROM debian:latest

RUN apt-get update && apt-get install -y \
    wget \
    tar \
    procps \
    coreutils \
    curl \
    screen && \
    rm -rf /var/lib/apt/lists/*

RUN wget -q https://download.java.net/java/GA/jdk17/0d483333a00540d886896bac774ff48b/35/GPL/openjdk-17_linux-x64_bin.tar.gz -O /tmp/OpenJDK17.tar.gz && \
    tar -xzf /tmp/OpenJDK17.tar.gz -C /opt && \
    mv /opt/jdk-17 /opt/java17 && \
    ln -s /opt/java17/bin/java /usr/bin/java && \
    rm -f /tmp/OpenJDK17.tar.gz

RUN mkdir -p /trollserver
COPY start-container.sh /start-container.sh
RUN chmod +x /start-container.sh

EXPOSE 25565
VOLUME /trollserver
ENTRYPOINT ["/start-container.sh"]
EOF

cat <<EOF > "$PROJECT_DIR/start-container.sh"
#!/bin/bash

cd /trollserver

if [ ! -f "arclight-forge.jar" ]; then
    wget -q --show-progress https://github.com/IzzelAliz/Arclight/releases/download/Trials%2F1.0.6/arclight-forge-1.20.1-1.0.6.jar -O arclight-forge.jar
fi

if ! java -jar arclight-forge.jar --version > /dev/null 2>&1; then
    echo "Error: Invalid JAR" && exit 1
fi

echo "eula=true" > eula.txt

wget -q https://github.com/playit-cloud/playit-agent/releases/download/v0.15.0/playit-linux-amd64 -O /usr/local/bin/playit
chmod +x /usr/local/bin/playit

playit &> playit.log &
sleep 10
URL=\$(grep -oP 'https?://\S+' playit.log | head -n1)
[ -n "\$URL" ] && echo "PLAYit URL: \$URL" > urlplayit.txt || exit 1

screen -S minecraft -d -m java -Xms6G -Xmx8G -jar arclight-forge.jar nogui
echo "Servidor iniciado en sesión screen"

tail -f /dev/null
EOF


cd "$PROJECT_DIR"
docker stop minecraft-playit-container 2>/dev/null && docker rm minecraft-playit-container 2>/dev/null
docker build -t minecraft-playit-server .
docker run -d \
  --name minecraft-playit-container \
  -p 25565:25565 \
  -v $(pwd)/trollserver:/trollserver \
  minecraft-playit-server


echo "=================================================="
echo "Servidor iniciado con PLAYit"
echo "URL: $(pwd)/trollserver/urlplayit.txt"
echo -e "\nPara interactuar:"
echo "1. Entrar al contenedor: docker exec -it minecraft-playit-container /bin/bash"
echo "2. Adjuntar a la sesión: screen -r minecraft"
echo "3. Salir de screen: Ctrl+A luego D"
echo "=================================================="

FROM node:20-alpine   

WORKDIR /app

COPY app/package*.json ./
RUN npm ci --only=production

COPY app/ .
#ARG :  Bien chi ton tai luc build image
# local : gia tri mac dinh neu khong truyen vao 
ARG BUILD_NUMBER=local 
#ENV= bien moi truong ton tai luc container chay
#${BUILD_NUMBER} lay gia tri tu ARG ben tren truyen sang 
ENV BUILD_NUMBER=${BUILD_NUMBER}

EXPOSE 3000

# --interval=30s : 30s check 1 lan --timeout=5s , --start-period=30s 30s moi bat dau thuc hien --retrues=3: fail 3 lan lien tuc bao die
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "index.js"]

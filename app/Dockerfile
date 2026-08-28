# Imagem base enxuta: nginx sobre Alpine, poucos megabytes e menos superficie de ataque
FROM nginx:1.27-alpine

LABEL org.opencontainers.image.title="Portal Arcanjo SA - CP04" \
      org.opencontainers.image.description="Portal institucional containerizado - FIAP DevOps CP04"

# Conteudo estatico do portal. O nginx ja serve este diretorio na porta 80 por padrao.
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://127.0.0.1/ || exit 1

CMD ["nginx", "-g", "daemon off;"]

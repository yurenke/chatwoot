FROM chatwoot/chatwoot:develop-ce

RUN sed -i 's/https:/http:/g' /etc/apk/repositories
USER root
RUN apk update && apk add --no-cache nodejs npm

ENV PNPM_HOME="/usr/local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN npm install -g pnpm

RUN chmod +x docker/entrypoints/vite.sh

EXPOSE 3036
ENTRYPOINT ["docker/entrypoints/vite.sh"]
FROM nginx:alpine

ARG RELEASE_MODE=stable

COPY index.html /usr/share/nginx/html/index.html
COPY healthz.html /usr/share/nginx/html/healthz.html

RUN if [ "$RELEASE_MODE" = "faulty" ]; then \
    rm -f /usr/share/nginx/html/healthz.html; \
    fi

EXPOSE 80
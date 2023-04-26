FROM python:3.9.16
COPY ./requirements.txt /app/requirements.txt
WORKDIR /app
RUN pip install -r requirements.txt
RUN pip install --upgrade pip
COPY ./flask_app /app
LABEL org.opencontainers.image.authors="nospam.joe@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/jtb75/tech-task"
LABEL org.opencontainers.image.vendor="jtb75"
EXPOSE 80
ENTRYPOINT [ "gunicorn" ]
CMD ["app:app", "-b", "0.0.0.0:80" ]
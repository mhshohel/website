FROM php:5.5.38-fpm-alpine

#RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli
#RUN docker-php-ext-install pdo pdo_mysql

#COPY ./src/html/pbsalesite/pbox14/ /var/www/html/

EXPOSE 9090

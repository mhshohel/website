FROM php:5.5.38-apache

#SET Default timezone for Date time zone Error
ADD ./etc/php/conf.d/timezone.ini /usr/local/etc/php/conf.d/

ENV APACHE_DOCUMENT_ROOT /var/www/html/website

# Change the root dir and log to console
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf && \
	sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf && \
	ln -sf /dev/stdout /var/log/apache2/access.log && \
	ln -sf /dev/stderr /var/log/apache2/error.log

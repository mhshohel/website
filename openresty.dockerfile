FROM openresty/openresty:alpine

#RUN ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log && \
#	ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

#RUN echo "daemon off;" >> /etc/nginx/nginx.conf
#CMD ["nginx", "-g", "daemon off;"]


#COPY ./usr/local/openresty/nginx/conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf


EXPOSE 80
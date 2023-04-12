FROM reopt/xpressbase AS xpress

FROM julia:1.8.5

# Install Xpress solver
ENV XPRESSDIR=/opt/xpressmp
ENV XPRESS=/opt/xpressmp/bin
ENV LD_LIBRARY_PATH=${XPRESSDIR}/lib:${LD_LIBRARY_PATH}
ENV LIBPATH=${XPRESSDIR}/lib:${LIBPATH}
ARG CLASSPATH=${XPRESSDIR}/lib/xprs.jar:${CLASSPATH}
ARG CLASSPATH=${XPRESSDIR}/lib/xprb.jar:${CLASSPATH}
ENV CLASSPATH=${XPRESSDIR}/lib/xprm.jar:${CLASSPATH}
ENV PATH=${XPRESSDIR}/bin:${PATH}

WORKDIR ${XPRESSDIR}
COPY --from=xpress  /opt/reopt/solver .
COPY xpauth.xpr .
RUN sed -i -e 's/\r$//' install.sh
RUN printf 's\n\nn\n\n.\n\n\n' | ./install.sh >> license_info.txt;

# # Install Julia packages
WORKDIR /opt/reopt/
COPY . .

CMD ["bash"]

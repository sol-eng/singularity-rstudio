slurmdir=/opt/slurm
libdir=$(slurmdir)/etc/spank
etcdir=$(slurmdir)/etc

all: singularity-exec.so

test:
	echo $(libdir) $(etcdir)

singularity-exec.so: main.cpp Makefile
	$(CXX) -std=c++17 -O2 -Wall -Wextra -fpic -shared -static-libstdc++ -static-libgcc -o $@ $<

prepare-plugstack-conf:
	mkdir -p $(etcdir)/plugstack.conf.d
	test -f $(etcdir)/plugstack.conf || \
        echo 'include $(etcdir)/plugstack.conf.d/*.conf' > $(etcdir)/plugstack.conf

transform-template:
	bash -c 'cat singularity-exec.conf.tmpl | \
                sed "s|LIBDIR|$(libdir)|g" |\
                sed "s|SLURMDIR|$(slurmdir)|g" \
                > singularity-exec.conf'
                

install: singularity-exec.so transform-template prepare-plugstack-conf singularity-exec.conf
	mkdir -p $(libdir)
	install slurm-singularity-wrapper.sh $(libdir)/
	install singularity-exec.so          $(libdir)/
	install singularity-exec.conf        $(etcdir)/plugstack.conf.d/

help:
	@echo "... all"
	@echo "... install"

clean:
	rm -f singularity-exec.so

.PHONY: help clean prepare-plugstack-conf


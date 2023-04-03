
all:
	snapcraft --debug --use-lxd

clean:
	snapcraft clean --use-lxd

try:
	snapcraft try --use-lxd
	sudo snap try ./prime --devmode

debug:
	snap run --shell mysqldump-explore

sync:
	cp mysqldump-explore.sh prime/bin/

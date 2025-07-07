.PHONY: all ${MAKECMDGOALS}

MOLECULE_SCENARIO ?= default
MOLECULE_DOCKER_IMAGE ?= ubuntu2004
GALAXY_API_KEY ?=
GITHUB_REPOSITORY ?= $$(git config --get remote.origin.url | cut -d':' -f 2 | cut -d. -f 1)
GITHUB_ORG = $$(echo ${GITHUB_REPOSITORY} | cut -d/ -f 1)
GITHUB_REPO = $$(echo ${GITHUB_REPOSITORY} | cut -d/ -f 2)
REQUIREMENTS = requirements.yml

all: install version lint test

test: install
	uv run molecule test -s ${MOLECULE_SCENARIO}

install:
	@uv sync

lint: install
	uv run yamllint .
	uv run ansible-lint .

requirements: roles collections

dependency create prepare converge idempotence side-effect verify destroy cleanup reset list:
	MOLECULE_KVM_IMAGE=${MOLECULE_KVM_IMAGE} \
	MOLECULE_DOCKER_COMMAND=${MOLECULE_DOCKER_COMMAND} \
	MOLECULE_DOCKER_IMAGE=${MOLECULE_DOCKER_IMAGE} \
	uv run molecule $@ -s ${MOLECULE_SCENARIO}

roles:
	[ -f ${REQUIREMENTS} ] && yq '.$@[] | .name' -r < ${REQUIREMENTS} \
		| xargs -L1 uv run ansible-galaxy role install --force || exit 0

collections:
	[ -f ${REQUIREMENTS} ] && yq '.$@[]' -r < ${REQUIREMENTS} \
		| xargs -L1 echo uv run ansible-galaxy -vvv collection install --force || exit 0

rebuild: destroy prepare create

ignore:
	uv run ansible-lint --generate-ignore

clean: destroy reset
	uv env remove $$(which python)

publish:
	@echo publishing repository ${GITHUB_REPOSITORY}
	@echo GITHUB_ORGANIZATION=${GITHUB_ORG}
	@echo GITHUB_REPOSITORY=${GITHUB_REPO}
	@uv run ansible-galaxy role import \
		--api-key ${GALAXY_API_KEY} ${GITHUB_ORG} ${GITHUB_REPO}

version: install
	@uv run molecule --version

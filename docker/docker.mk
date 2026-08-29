DOCKER            ?= docker
DOCKER_OPTS       ?=
DOCKER_REPO       ?= batoceralinux
DOCKER_IMAGE_NAME ?= batocera.linux-build
DOCKER_PLATFORM   ?= linux/amd64,linux/arm64

ifdef IMAGE_NAME
$(warning IMAGE_NAME will be removed in the future, please migrate to DOCKER_IMAGE_NAME)
DOCKER_IMAGE_NAME := $(IMAGE_NAME)
endif

DOCKER_IMAGE = $(DOCKER_REPO)/$(DOCKER_IMAGE_NAME)

ifndef BATCH_MODE
DOCKER_OPTS += -i
endif

ifdef DIRECT_BUILD
define RUN_DOCKER
	@$(error This is a direct build environment, cannot run Docker)
endef
else
UID  := $(shell id -u)
GID  := $(shell id -g)

# Opt-in extra bind mount for iterative package development: point
# KERNEL_SRCDIR at a local git checkout and it shows up in the container
# at /kernel-src, ready for a <PKG>_OVERRIDE_SRCDIR=/kernel-src in local.mk
# (see output/<board>/local.mk - BR2_PACKAGE_OVERRIDE_FILE's default
# location). This is buildroot's own documented mechanism for "edit
# source, rebuild, no commit/push needed" - see buildroot manual's "Using
# Buildroot during development". Without this mount, only a version
# string that buildroot has ALREADY cached under is enough to make it
# silently keep reusing a stale download() forever, even after new
# commits land upstream - this bit the odroid-m1-panfrost kernel branch
# for two full iterations (see Joplin "buildroot 커널 캐시 오염" note).
ifdef KERNEL_SRCDIR
DOCKER_OPTS += -v $(KERNEL_SRCDIR):/kernel-src
endif

# git worktree checkouts (as opposed to a plain clone) keep their real
# .git contents in the *main* checkout's .git/worktrees/<name>/, outside
# PROJECT_DIR entirely - the worktree's own ".git" is just a one-line
# pointer file with an absolute path to that location. Since only
# PROJECT_DIR gets bind-mounted above, `git` commands run inside the
# container (e.g. batocera-system.mk's BATOCERA_SYSTEM_COMMIT) can't
# resolve it and silently fail ("fatal: not a git repository"), leaving
# batocera.version's commit suffix empty. Mount the real common dir at
# the same absolute host path so it resolves identically in-container.
GIT_COMMON_DIR := $(shell cd $(PROJECT_DIR) && git rev-parse --git-common-dir 2>/dev/null | xargs -I{} realpath {} 2>/dev/null)
ifneq ($(GIT_COMMON_DIR),)
ifeq ($(filter $(PROJECT_DIR)/%,$(GIT_COMMON_DIR)),)
DOCKER_OPTS += -v $(GIT_COMMON_DIR):$(GIT_COMMON_DIR):ro
endif
endif

define RUN_DOCKER
	$(DOCKER) run -t --init --rm \
		-v $(PROJECT_DIR):/build \
		-v $(DL_DIR):/build/buildroot/dl \
		-v $(OUTPUT_DIR)/$(1):/$(1) \
		-v $(CCACHE_DIR):/home/batocera/.buildroot-ccache \
		-w /$(1) \
		-e HOST_UID=$(UID) \
		-e HOST_GID=$(GID) \
		$(DOCKER_OPTS) \
		$(DOCKER_IMAGE)
endef
endif

define RUN_DOCKER_TARGET
	$(call RUN_DOCKER,$*)
endef

.PHONY: _check_docker
_check_docker:
ifdef DIRECT_BUILD
	$(error This is a direct build environment)
endif
	$(call REQUIRE,$(DOCKER))

DOCKER_IMAGE_STAMP = $(PROJECT_DIR)/.ba-docker-image-available
DOCKER_IMAGE_AVAILABLE := $(if $(DIRECT_BUILD),,$(DOCKER_IMAGE_STAMP))

define DOCKER_CHECK_BUILDER
if ! $(DOCKER) buildx inspect batocera-builder >/dev/null 2>&1 ; then \
	$(call MESSAGE,Creating docker builder 'batocera-builder'); \
	$(DOCKER) buildx create --name batocera-builder; \
fi
endef

define DOCKER_ECHO_ACTION_MESSAGE
$(call MESSAGE,$(DOCKER_ACTION_MESSAGE) docker image $(DOCKER_IMAGE))
endef

$(DOCKER_IMAGE_STAMP): | _check_docker
	@if [ '$(DOCKER_ACTION)' = 'build' ]; then \
		$(DOCKER_CHECK_BUILDER); \
		$(DOCKER_ECHO_ACTION_MESSAGE); \
		$(DOCKER) buildx build --builder batocera-builder \
				--platform $(DOCKER_PLATFORM) \
				-t $(DOCKER_IMAGE) $(PROJECT_DIR)/docker; \
		$(DOCKER) buildx build --builder batocera-builder \
				--load -t $(DOCKER_IMAGE) $(PROJECT_DIR)/docker; \
	else \
		$(DOCKER_ECHO_ACTION_MESSAGE); \
		$(DOCKER) pull $(DOCKER_IMAGE); \
	fi
	@touch $@

.PHONY: pull-docker-image
pull-docker-image: DOCKER_ACTION = pull
pull-docker-image: DOCKER_ACTION_MESSAGE = Pulling
pull-docker-image: $(DOCKER_IMAGE_AVAILABLE)

.PHONY: build-docker-image
build-docker-image: DOCKER_ACTION = build
build-docker-image: DOCKER_ACTION_MESSAGE = Building
build-docker-image: $(DOCKER_IMAGE_AVAILABLE)

.PHONY: clean-for-docker-image
clean-for-docker-image:
	-@rm -f $(DOCKER_IMAGE_STAMP) >/dev/null

.PHONY: update-docker-image
update-docker-image: clean-for-docker-image
	@$(MAKE) pull-docker-image DOCKER_ACTION_MESSAGE=Updating

.PHONY: rebuild-docker-image
rebuild-docker-image: clean-for-docker-image
	@$(MAKE) build-docker-image DOCKER_ACTION_MESSAGE=Rebuilding

.PHONY: publish-docker-image
publish-docker-image: | _check_docker
	@$(DOCKER_CHECK_BUILDER)
	@$(call MESSAGE,Publishing docker image $(DOCKER_IMAGE))
	@$(DOCKER) buildx build --builder batocera-builder \
		--push --platform $(DOCKER_PLATFORM) \
		-t $(DOCKER_IMAGE) \
		$(PROJECT_DIR)/docker

#-*-makefile-*-   ; force emacs to enter makefile-mode

# %CopyrightBegin%
#
# SPDX-License-Identifier: Apache-2.0
#
# Copyright Ericsson AB 2003-2025. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# %CopyrightEnd%

include $(ERL_TOP)/make/target.mk

EBIN = ../../ebin

include $(ERL_TOP)/make/$(TARGET)/otp.mk

# ----------------------------------------------------
# Application version
# ----------------------------------------------------
include ../../vsn.mk

VSN = $(SNMP_VSN)

# ----------------------------------------------------
# Release directory specification
# ----------------------------------------------------
RELSYSDIR = $(RELEASE_PATH)/lib/snmp-$(VSN)


# ----------------------------------------------------
# Target Specs
# ----------------------------------------------------

include modules.mk

ERL_FILES = $(MODULES:%=%.erl)

HRL_FILES = $(HRLS:%=%.hrl)

TARGET_FILES = $(MODULES:%=$(EBIN)/%.$(EMULATOR))


# ----------------------------------------------------
# SNMP FLAGS
# ----------------------------------------------------
ifeq ($(SNMP_DEFAULT_VERBOSITY),)
  SNMP_FLAGS = -Ddefault_verbosity=silence
else
  SNMP_FLAGS = -Ddefault_verbosity=$(SNMP_DEFAULT_VERBOSITY)
endif

# SNMP_DEBUG=d
ifeq ($(SNMP_DEBUG),d)
  SNMP_FLAGS += -Dsnmp_debug
endif


# ----------------------------------------------------
# FLAGS
# ----------------------------------------------------

ERL_COMPILE_FLAGS += -pa $(ERL_TOP)/lib/snmp/ebin

ifeq ($(SNMP_WARNING_AS_ERROR),)
  ERL_COMPILE_FLAGS += -Werror
else
  ifeq ($(SNMP_WARNING_AS_ERROR),true)
    ERL_COMPILE_FLAGS += -Werror
  endif
endif

ifeq ($(WARN_UNUSED_VARS),)
  ERL_COMPILE_FLAGS += +warn_unused_vars
else
  ifeq ($(WARN_UNUSED_VARS),true)
    ERL_COMPILE_FLAGS += +warn_unused_vars
  endif
endif

ERL_COMPILE_FLAGS += -I../../include \
                     -I../app \
                     -I../compile \
                     -Dversion=\"$(VSN)$(PRE_VSN)\" \
                     +'{parse_transform,sys_pre_attributes}' \
                     +'{attribute,insert,app_vsn,$(APP_VSN)}' \
                     -I$(ERL_TOP)/lib/stdlib \
                     $(SNMP_FLAGS)


# ----------------------------------------------------
# Targets
# ----------------------------------------------------

$(filter-out opt, $(TYPES)):
	@${MAKE} TYPE=$@ opt

opt: $(TARGET_FILES)


clean:
	rm -f $(TARGET_FILES)
	rm -f snmp_pdus_basic.erl
	rm -f snmp_pdus_basic.asn1db
	rm -f core *~

docs:

info:
	@echo ""
	@echo "MODULES:           $(MODULES)"
	@echo "HRLS:              $(HRLS)"
	@echo ""
	@echo "ASN1_SPECS:        $(ASN1_SPECS)"
	@echo ""
	@echo "TARGET_FILES:      $(TARGET_FILES)"
	@echo ""
	@echo "ERL_COMPILE_FLAGS: $(ERL_COMPILE_FLAGS)"
	@echo ""


# ----------------------------------------------------
# Release Target
# ---------------------------------------------------- 
include $(ERL_TOP)/make/otp_release_targets.mk

release_spec: opt
	$(INSTALL_DIR) "$(RELSYSDIR)/src"
	$(INSTALL_DIR) "$(RELSYSDIR)/src/misc"
	$(INSTALL_DATA) $(ERL_FILES) $(HRL_FILES) "$(RELSYSDIR)/src/misc"
	$(INSTALL_DIR) "$(RELSYSDIR)/ebin"
	$(INSTALL_DATA) $(TARGET_FILES) "$(RELSYSDIR)/ebin"

release_docs_spec:

include depend.mk

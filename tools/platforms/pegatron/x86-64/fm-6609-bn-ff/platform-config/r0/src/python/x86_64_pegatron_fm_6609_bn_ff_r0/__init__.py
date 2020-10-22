from onl.platform.base import *
from onl.platform.pegatron import *

class OnlPlatform_x86_64_pegatron_fm_6609_bn_ff_r0(OnlPlatformPegatron):
    PLATFORM='x86-64-pegatron-fm-6609-bn-ff-r0'
    MODEL="FM-6609-BN-FF"
    SYS_OBJECT_ID=".2"
    PORT_COUNT=0
    PORT_CONFIG="None"

    def baseconfig(self):
	self.insmod('pega_platform')
	return True

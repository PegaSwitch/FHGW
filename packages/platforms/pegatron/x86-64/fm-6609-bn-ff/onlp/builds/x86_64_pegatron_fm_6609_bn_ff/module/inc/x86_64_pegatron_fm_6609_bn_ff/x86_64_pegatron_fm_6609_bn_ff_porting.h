/************************************************************
 * <bsn.cl fy=2014 v=onl>
 * 
 *        Copyright 2014, 2015 Big Switch Networks, Inc.       
 * 
 * Licensed under the Eclipse Public License, Version 1.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 * 
 *        http://www.eclipse.org/legal/epl-v10.html
 * 
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
 * either express or implied. See the License for the specific
 * language governing permissions and limitations under the
 * License.
 * 
 * </bsn.cl>
 ************************************************************
 *
 *
 *
 ***********************************************************/

/********************************************************//**
 *
 * @file
 * @brief x86_64_pegatron_fm_6609_bn_ff Porting Macros.
 *
 * @addtogroup x86_64_pegatron_fm_6609_bn_ff-porting
 * @{
 *
 ***********************************************************/
#ifndef __X86_64_PEGATRON_FM_6609_BN_FF_PORTING_H__
#define __X86_64_PEGATRON_FM_6609_BN_FF_PORTING_H__


/* <auto.start.portingmacro(ALL).define> */
#if X86_64_PEGATRON_FM_6609_BN_FF_CONFIG_PORTING_INCLUDE_STDLIB_HEADERS == 1
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <memory.h>
#endif

#ifndef X86_64_PEGATRON_FM_6609_BN_FF_MALLOC
    #if defined(GLOBAL_MALLOC)
        #define X86_64_PEGATRON_FM_6609_BN_FF_MALLOC GLOBAL_MALLOC
    #elif X86_64_PEGATRON_FM_6609_BN_FF_CONFIG_PORTING_STDLIB == 1
        #define X86_64_PEGATRON_FM_6609_BN_FF_MALLOC malloc
    #else
        #error The macro X86_64_PEGATRON_FM_6609_BN_FF_MALLOC is required but cannot be defined.
    #endif
#endif

#ifndef X86_64_PEGATRON_FM_6609_BN_FF_FREE
    #if defined(GLOBAL_FREE)
        #define X86_64_PEGATRON_FM_6609_BN_FF_FREE GLOBAL_FREE
    #elif X86_64_PEGATRON_FM_6609_BN_FF_CONFIG_PORTING_STDLIB == 1
        #define X86_64_PEGATRON_FM_6609_BN_FF_FREE free
    #else
        #error The macro X86_64_PEGATRON_FM_6609_BN_FF_FREE is required but cannot be defined.
    #endif
#endif

#ifndef X86_64_PEGATRON_FM_6609_BN_FF_MEMSET
    #if defined(GLOBAL_MEMSET)
        #define X86_64_PEGATRON_FM_6609_BN_FF_MEMSET GLOBAL_MEMSET
    #elif X86_64_PEGATRON_FM_6609_BN_FF_CONFIG_PORTING_STDLIB == 1
        #define X86_64_PEGATRON_FM_6609_BN_FF_MEMSET memset
    #else
        #error The macro X86_64_PEGATRON_FM_6609_BN_FF_MEMSET is required but cannot be defined.
    #endif
#endif

#ifndef X86_64_PEGATRON_FM_6609_BN_FF_MEMCPY
    #if defined(GLOBAL_MEMCPY)
        #define X86_64_PEGATRON_FM_6609_BN_FF_MEMCPY GLOBAL_MEMCPY
    #elif X86_64_PEGATRON_FM_6609_BN_FF_CONFIG_PORTING_STDLIB == 1
        #define X86_64_PEGATRON_FM_6609_BN_FF_MEMCPY memcpy
    #else
        #error The macro X86_64_PEGATRON_FM_6609_BN_FF_MEMCPY is required but cannot be defined.
    #endif
#endif

#ifndef X86_64_PEGATRON_FM_6609_BN_FF_STRNCPY
    #if defined(GLOBAL_STRNCPY)
        #define X86_64_PEGATRON_FM_6609_BN_FF_STRNCPY GLOBAL_STRNCPY
    #elif X86_64_PEGATRON_FM_6609_BN_FF_CONFIG_PORTING_STDLIB == 1
        #define X86_64_PEGATRON_FM_6609_BN_FF_STRNCPY strncpy
    #else
        #error The macro X86_64_PEGATRON_FM_6609_BN_FF_STRNCPY is required but cannot be defined.
    #endif
#endif

#ifndef X86_64_PEGATRON_FM_6609_BN_FF_VSNPRINTF
    #if defined(GLOBAL_VSNPRINTF)
        #define X86_64_PEGATRON_FM_6609_BN_FF_VSNPRINTF GLOBAL_VSNPRINTF
    #elif X86_64_PEGATRON_FM_6609_BN_FF_CONFIG_PORTING_STDLIB == 1
        #define X86_64_PEGATRON_FM_6609_BN_FF_VSNPRINTF vsnprintf
    #else
        #error The macro X86_64_PEGATRON_FM_6609_BN_FF_VSNPRINTF is required but cannot be defined.
    #endif
#endif

#ifndef X86_64_PEGATRON_FM_6609_BN_FF_SNPRINTF
    #if defined(GLOBAL_SNPRINTF)
        #define X86_64_PEGATRON_FM_6609_BN_FF_SNPRINTF GLOBAL_SNPRINTF
    #elif X86_64_PEGATRON_FM_6609_BN_FF_CONFIG_PORTING_STDLIB == 1
        #define X86_64_PEGATRON_FM_6609_BN_FF_SNPRINTF snprintf
    #else
        #error The macro X86_64_PEGATRON_FM_6609_BN_FF_SNPRINTF is required but cannot be defined.
    #endif
#endif

#ifndef X86_64_PEGATRON_FM_6609_BN_FF_STRLEN
    #if defined(GLOBAL_STRLEN)
        #define X86_64_PEGATRON_FM_6609_BN_FF_STRLEN GLOBAL_STRLEN
    #elif X86_64_PEGATRON_FM_6609_BN_FF_CONFIG_PORTING_STDLIB == 1
        #define X86_64_PEGATRON_FM_6609_BN_FF_STRLEN strlen
    #else
        #error The macro X86_64_PEGATRON_FM_6609_BN_FF_STRLEN is required but cannot be defined.
    #endif
#endif

/* <auto.end.portingmacro(ALL).define> */


#endif /* __X86_64_PEGATRON_FM_6609_BN_FF_PORTING_H__ */
/* @} */

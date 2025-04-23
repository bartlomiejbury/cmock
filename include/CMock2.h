#pragma once

#include <gmock/gmock.h>

template<typename T>
class CMockMocker {
  public:
    CMockMocker() { 
        if (instance) {
            printf("Mock object already created\n");
            abort();
        }
        instance = (T *)this;
    }
    ~CMockMocker() { instance = nullptr;}
    static T *cmock_get_instance() { return instance; }

  private:
    static inline T *instance = NULL;
};


#define CMOCK_INTERNAL_RETURN_TYPE(_Signature) \
    typename ::testing::internal::Function<GMOCK_PP_REMOVE_PARENS(_Signature)>::Result

#define CMOCK_INTERNAL_FUNCTION(_ClassName, _FunctionName, _N, _Signature)                                                    \
    extern "C" CMOCK_INTERNAL_RETURN_TYPE(_Signature) proxy_##_FunctionName(GMOCK_PP_REPEAT(GMOCK_INTERNAL_PARAMETER, _Signature, _N)) { \
        _ClassName *mock = _ClassName::cmock_get_instance();                                                                  \
        if (mock != nullptr) {                                                                                                \
            return mock->_FunctionName(GMOCK_PP_REPEAT(GMOCK_INTERNAL_FORWARD_ARG, _Signature, _N));                          \
        } else {                                                                                                              \
            printf("Mock object is not exist\n");                                                                             \
            abort();                                                                                                          \
        }                                                                                                                     \
    }

#define CMOCK_INTERNAL_CONST_FUNCTION(_ClassName, _FunctionName, _N, _Signature)                                              \
    extern "C" CMOCK_INTERNAL_RETURN_TYPE(_Signature) proxy_##_FunctionName(GMOCK_PP_REPEAT(GMOCK_INTERNAL_PARAMETER, _Signature, _N)) { \
        _ClassName *mock = _ClassName::cmock_get_instance();                                                                  \
        if (mock != nullptr) {                                                                                                \
            return mock->_FunctionName(GMOCK_PP_REPEAT(GMOCK_INTERNAL_FORWARD_ARG, _Signature, _N));                          \
        } else {                                                                                                              \
            return _FunctionName(GMOCK_PP_REPEAT(GMOCK_INTERNAL_FORWARD_ARG, _Signature, _N));                                \
        }                                                                                                                     \
    }

#define CMOCK_MOCK_FUNCTION(_ClassName,  _Ret, _FunctionName, _Args) \
    CMOCK_INTERNAL_FUNCTION(_ClassName, _FunctionName, GMOCK_PP_NARG0 _Args, (GMOCK_INTERNAL_SIGNATURE(_Ret, _Args)))

#define CMOCK_MOCK_CONST_FUNCTION(_ClassName,  _Ret, _FunctionName, _Args, _dummy) \
    CMOCK_INTERNAL_CONST_FUNCTION(_ClassName, _FunctionName, GMOCK_PP_NARG0 _Args, (GMOCK_INTERNAL_SIGNATURE(_Ret, _Args)))

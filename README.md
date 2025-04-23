# Mock.py

`mock.py` is a Python script designed to assist with mocking C functions and managing object files in a CMake-based project. It provides functionality to generate mock sources, check header files, and reroute object files for testing purposes.

## Features

- **Reroute Object Files**: Redirects symbols in object files to use mocked implementations.
- **Generate Mock Sources**: Creates mock source files from header files for testing.
- **Check Header Files**: Validates header files and identifies classes with mockable methods.

## Requirements

- Python 3.11 or later
- GoogleTest 1.11.0 or later
- GNU `objcopy` (part of the GNU Binutils package)
- `nm` command (for symbol inspection)

## Usage

The script provides three main commands: `reroute`, `generate`, and `checkHeaders`. Each command is described below.

### 1. Generate Mock Cpp files

Generate cpp files based on Mock header files

#### Command:
```bash
python3 mock.py generate --headers <mock_header_files> --output <output_directory>
```

### 2. Reroute Object Files

Redirects symbols in object files to use mocked implementations.

#### Command:
```bash
python3 mock.py reroute --mocks <mock_object_files> --objects <object_files> [--output <output_directory>]
```

### 3. List generated Mock cpp files

Usefull for cmacke to get list of generated source files separated by ```;```.

#### Command:
```bash
python3 mock.py list --headers <mock_header_files> --output <output_directory>
```

# Mock header file

Mock header file should have google test style and inherit from ```CMockMocker<SystemMock>```

```
#include "CMock2.h"

class SystemMock : public CMockMocker<SystemMock> {
  public:
    MOCK_METHOD(ssize_t, read, (int fd, void *buf, size_t nbytes));
    MOCK_METHOD(ssize_t, write, (int fd, const void *buf, size_t n)), (const);
};
```

There are two variants of mocked function.

Normal function will abort when Mock object is not defined
and const function which call original one when Mock object is not defined

Moc.py insternally will create cpp file with content:

```
#include "SystemMock.h"

CMOCK_MOCK_FUNCTION(SystemMock, ssize_t, read, (int fd, void *buf, size_t nbytes));
CMOCK_CONST_MOCK_FUNCTION(SystemMock, ssize_t, write, (int fd, const void *buf, size_t n), (const));
```

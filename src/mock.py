import argparse
import subprocess
import os
import re
import tempfile

prefix = "proxy_"

class MethodContainer:
    def __init__(self, signature):
        self.isConst = "(const)" in signature
        self.signature = signature

    def getProxy(self, className):
        if self.isConst:
            return f"CMOCK_MOCK_CONST_FUNCTION({className}, {self.signature});"
        else:
            return f"CMOCK_MOCK_FUNCTION({className}, {self.signature});"


class ClassContainer:
    def __init__(self, className, classBody):
        self.className = className
        self.methods = []

        pos = 0
        while pos >= 0:
            pos = classBody.find("MOCK_METHOD", pos)
            if pos >= 0:
                pos = self.bracket_match(classBody, pos+ len('MOCK_METHOD'))

    def bracket_match(self, text, index):
        diffCounter = 0
        start = index
        for pos in range(index, len(text), 1):
            if text[pos] == '(':
                diffCounter += 1
                if diffCounter == 1:
                    start = pos + 1

            elif text[pos] == ')':
                diffCounter -= 1
                if diffCounter == 0:
                    func = re.sub("\n *", ' ', text[start:pos])
                    self.methods.append(MethodContainer(func))
                    return pos + 1
        return -1

    def getProxy(self):
        return "\n".join([m.getProxy(self.className) for m in self.methods])

def find_classes(text):
    result = []
    className = ''
    classBody = ''
    pos = -1

    while True:
        pos = text.find("class", pos+1)
        if pos < 0:
            break

        groups = re.search(r"class (\w+)", text[pos:])
        className = groups.group(1)

        next = text.find("class", pos+1)
        if next >= 0:
            classBody = text[pos:next]
        else:
            classBody = text[pos:]

        pos = pos+1
        if f"CMockMocker<{className}>" in classBody:
            result.append(ClassContainer(className, classBody))

    return result


def getFunctionsFromMockFile(file):
    output = subprocess.check_output(f"nm --defined-only {file} | tr -s ' ' | awk '{{ if ($2 == \"T\") {{ print $3 }}}}'", shell=True, text=True)
    return set([text.removeprefix(prefix) for text in output.split() if text.startswith(prefix)])


def getUndefinedSymbolsFromObj(file):
    output = subprocess.check_output(f"nm --undefined-only {file} | tr -s ' ' | cut -d ' ' -f 3", shell=True, text=True)
    return set(output.split())


def createReroutedTxt(file, usedMocks, tmpDirName):
    file = os.path.basename(file).replace(".h", "-rerouted.txt")
    reroutedFile = os.path.join(tmpDirName, file)
    with open(reroutedFile, "w") as file:
        for function in usedMocks:
            file.write(f"{function} {prefix}{function}\n")
    return reroutedFile


def redirectSymbols(file, outputFile, reroutedFile):
    subprocess.run(f"objcopy --redefine-syms={reroutedFile} {file} {outputFile}", shell=True)
    print(f"Redirected object file: {file} to: {outputFile}")


def handleRerouteCommand(args):

    with tempfile.TemporaryDirectory() as tmpdirname:

        mockedFunctions = set()

        for file in args.mocks:
            mockedFunctions.update(getFunctionsFromMockFile(file))

        for file in args.objects:
            undefinedSymbols = getUndefinedSymbolsFromObj(file)
            usedMocks = undefinedSymbols.intersection(mockedFunctions)

            if len(usedMocks) != 0:
                reroutedFile = createReroutedTxt(file, usedMocks, tmpdirname)

                if args.output:
                    outputFile = os.path.basename(file).replace(".o", "-rerouted.o")
                    outputFile = os.path.join(args.output, outputFile)
                else:
                    outputFile = file

                redirectSymbols(file, outputFile, reroutedFile)


def _get_output_file(outputDir, filePath):
    fileName = os.path.basename(filePath)
    fileWithoutExt = os.path.splitext(fileName)[0]
    fileOutput = os.path.join(outputDir, fileWithoutExt + ".cpp")
    return fileOutput


def handleGenerateCommand(args):

    result = []
    for filePath in args.headers:

        fileName = os.path.basename(filePath)
        fileOutput = _get_output_file(args.output, filePath)

        with open(filePath, "r") as f:
            fileContent = f.read()

            cmock = f'#include "{fileName}"\n\n'
            classes = find_classes(fileContent)
            if len(classes) > 0:
                for classContainer in classes:
                    cmock += classContainer.getProxy()

                print(f"Create proxy for {fileName}")
                result.append(fileOutput)
                with open(fileOutput, 'w') as f2:
                    f2.write(cmock)

    return result

def handleListCommand(args):

    result = []
    for filePath in args.headers:
        fileOutput = _get_output_file(args.output, filePath)

        with open(filePath, "r") as f:
            fileContent = f.read()
            classes = find_classes(fileContent)
            if len(classes) > 0:
                result.append(fileOutput)

    print(";".join(result), end='')


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Mocking C function')
    subparsers = parser.add_subparsers(dest='command')

    reroute = subparsers.add_parser('reroute', help='reroute objcts')
    reroute.add_argument('--mocks', type=str, nargs='+', help='mock object files', required=True)
    reroute.add_argument('--objects', type=str, nargs='+', help='source object files', required=True)
    reroute.add_argument('--output', type=str, help='rerouted objects output directory')

    generate = subparsers.add_parser('generate', help='generate mocks sources')
    generate.add_argument('--headers', type=str, nargs='+', help='mock header files', required=True)
    generate.add_argument('--output', type=str, help='mock output directory', required=True)

    list = subparsers.add_parser('list', help='list generated mocks')
    list.add_argument('--headers', type=str, nargs='+', help='mock header files', required=True)
    list.add_argument('--output', type=str, help='mock output directory')

    args = parser.parse_args()
    if args.command == 'reroute':
        handleRerouteCommand(args)
    elif args.command == 'generate':
        handleGenerateCommand(args)
    elif args.command == 'list':
        handleListCommand(args)

#!/usr/bin/python
"""This module transforms correctly formatted memcached logs to csv

The format of logs should be a tar archive containing the output named 'stdout.log'
and one file containing the command line used named 'command.sh', the decompressed
version of the archive can also be used by passing the --notar flag
"""

import argparse
import csv
import re
import tarfile
import sys

REMAP = ['', 'threads count: ([0-9]+)', 'concurrency: ([0-9]+)', 'get_prop=([0-9.]+)',
         '\'-F\' \'[/a-z._]+([0-9]+-[0-9]+)_[0-9]+-[0-9]+',
         '\'-F\' \'[/a-z._]+[0-9]+-[0-9]+_([0-9]+-[0-9]+)', 'TPS: ([0-9]+)']
GLOBMAP = ['name', 'threads', 'concurrency', 'get_prop', 'key_size', 'value_size', 'tps']
LOCALMAP = ['time', 'ops', 'tps', 'net', 'miss', 'min', 'max', 'avg', 'dev', 'dist']

def _check_args(parser, argv):
    args = parser.parse_args(argv)
    for local in args.localf:
        if local not in LOCALMAP:
            parser.error(local + ' is not a valid argument')
    for glob in args.globf:
        if glob not in GLOBMAP:
            parser.error(glob + ' is not a valid argument')
    for action in args.action:
        if action not in ['Get', 'Set', 'Total']:
            parser.error(action + ' is not a valid argument')
    return args

def _dirname(filename):
    """Strip filename from filepath"""
    match = re.match('([a-zA-Z0-9/_.]+)/[a-zA-Z0-9_.]+', filename)
    if match != None:
        return match.group(1)

def _init_inputs(args):
    """Open all files/tarfiles and returns a dict which associate the file/tarfile name
    with the opened stream"""
    inputs = {}
    tars = []
    for col in args.logdir:
        if args.notar:
            inputs[col + '/stdout.log'] = open(col + '/stdout.log')
            inputs[col + '/command.sh'] = open(col + '/command.sh')
        else:
            tar = tarfile.open(col)
            tars.append(tar)
            inputs[col + '/stdout.log'] = tar.extractfile(col.split('.')[0] + '/stdout.log')
            inputs[col + '/command.sh'] = tar.extractfile(col.split('.')[0] + '/command.sh')
    return (tars, inputs)

def _teardown_inputs(tars, inputs):
    """Close all files/tarfiles streams"""
    for tar in tars:
        tar.close()
    for _, stream in inputs.items():
        stream.close()

def _init_writers(args):
    """Create all csvwriter for outputs and returns a dict which associate the action
    with the writer"""
    files = {}
    writers = {}
    for action in args.action:
        files[action] = open(action + '_' + args.o, 'w', newline='')
        writers[action] = csv.writer(files[action], delimiter=args.s)

    for _, writer in writers.items():
        writer.writerow(args.globf + args.localf)

    return (files, writers)

def _teardown_writers(files):
    """Close all files opened by init_writers"""
    for _, opened in files.items():
        opened.close()

def _extract_locals(splitline, args):
    """Extract each specified local field in a line"""
    ret = []
    for col in args.localf:
        ret.append(str(splitline[LOCALMAP.index(col)+1]).strip('\n'))
    return ret

def _extract_globals(line, glob, name, args):
    """Extract global fields if there is any in the line"""
    for col in args.globf:
        if col == 'name':
            if name not in glob:
                glob[name] = {}
            glob[name][col] = name
        else:
            match = re.search(REMAP[GLOBMAP.index(col)], line)
            if match is not None:
                if name not in glob:
                    glob[name] = {}
                glob[name][col] = match.group(1)

def _write_globs(writers, glob):
    """Write global fields to a csv file (this is used if there is no local fields)"""
    for _, row in glob.items():
        writers[list(writers.keys()).pop()].writerow(
            [row[key] for key in sorted(list(row.keys()), key=GLOBMAP.index)])

def _write_all(writers, line, glob, name, args):
    """Write all fields in a line in the good csv file (which is either Get, Set, or Total)"""
    splitline = re.split(' +', str(line))
    if splitline[0] == 'Get' or splitline[0] == 'Set' or splitline[0] == 'Total':
        action = splitline[0]
    if splitline[0] == 'Period':
        if action in writers:
            row = glob[_dirname(name)]
            globs = [row[key] for key in sorted(list(row.keys()), key=GLOBMAP.index)]
            writers[action].writerow(globs + _extract_locals(splitline, args))

def main(argv=None):
    """Main function, parse arguments and create csv files from tar or directories input"""
    try:
        parser = argparse.ArgumentParser(description='Transform log output to csv file',
                                         formatter_class=argparse.RawDescriptionHelpFormatter,
                                         epilog=('Global fields can be: ' + str(GLOBMAP) + '\n'
                                                 'Local fields can be: ' + str(LOCALMAP)))

        parser.add_argument('--globf', metavar='G', nargs='+',
                            default=['threads', 'concurrency', 'get_prop', 'key_size',
                                     'value_size', 'tps'],
                            help='the global fields names')
        parser.add_argument('--localf', metavar='L', nargs='+',
                            default=[], help='the local fields names')
        parser.add_argument('--action', metavar='A', nargs='+', default=['Total'],
                            help='Create on file per action (Get, Set, Total)')
        parser.add_argument('-s', metavar='sep', default=' ',
                            help='the output separator, must be one character')
        parser.add_argument('-o', metavar='output', default='bench.csv',
                            help='the output file, default to bench.csv')
        parser.add_argument('--notar', action='store_const', const=True, default=False,
                            help='use normal directories instead of tar archives')
        parser.add_argument('logdir', metavar='dir', nargs='+',
                            help='the dir from which values are extracted')

        args = _check_args(parser, argv)

        tars, inputs = _init_inputs(args)
        files, writers = _init_writers(args)
        glob = {}

        for name, stream in inputs.items():
            for line in stream.readlines():
                _extract_globals(str(line), glob, _dirname(name), args)

        if args.localf == []:
            _write_globs(writers, glob)
        else:
            for name, stream in inputs.items():
                if re.search('.*/stdout.log', name) != None:
                    stream.seek(0)
                    for line in stream:
                        _write_all(writers, line, glob, name, args)

        _teardown_writers(files)
        _teardown_inputs(tars, inputs)
    except SystemExit as exception:
        return 1
    except FileNotFoundError as exception:
        print(str(exception), file=sys.stderr)
        return exception.errno
    except IsADirectoryError as exception:
        print(str(exception), file=sys.stderr)
        print('Use the --notar flag to use this function on directory instead of archives')
        return exception.errno

if __name__ == "__main__":
    exit(main())

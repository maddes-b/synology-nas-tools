#!/usr/bin/env python
# -*- coding: utf-8; tab-width: 4; indent-tabs-mode: nil; py-indent-offset: 4 -*-

##  Output certificate information on DSM (7.x) from related INFO file.
##  Copyright (C) 2024  Matthias "Maddes" Bücher
##
##  This program is free software; you can redistribute it and/or modify
##  it under the terms of the GNU General Public License as published by
##  the Free Software Foundation; either version 2 of the License, or
##  (at your option) any later version.
##
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
##
##  You should have received a copy of the GNU General Public License along
##  with this program; if not, write to the Free Software Foundation, Inc.,
##  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
##  Or visit https://www.gnu.org/licenses/old-licenses/gpl-2.0.html.en

## Information:
## - Developed/Tested for Python3 on DS1821+ with DSM 7.2.1
##   Recommended to place into /usr/local/sbin (needs root permissions to access info file)
##   Use parameter '-h' to get help on script
## - Reason no Let's Encrypt dns-01 challenge possible in my current situation, so have to distribute via copying to services
## - Idea of filtering on certificate description was adopted from rubinho's script
##   see https://www.synology-forum.de/threads/frage-ssl-zertifikat-webserver-per-shell-einfuegen-und-verteilen.91243/#post-785587

### Python 2 future-compatible workarounds: (see: http://python-future.org/compatible_idioms.html)
## a) prevent interpreting print(a,b) as a tuple
from __future__ import print_function
## b) interpret all literals as unicode
from __future__ import unicode_literals

import sys
import json
import argparse
import os


## Define DSM certificate paths (DSM 7.2 as of 2024-02)
CERT_SYSTEM_ROOT_DIR = "/usr/syno/etc/certificate"
CERT_SYSTEM_ARCHIVE_DIR = os.path.join(CERT_SYSTEM_ROOT_DIR, "_archive")
CERT_INFO_PATH = os.path.join(CERT_SYSTEM_ARCHIVE_DIR, "INFO")
#
CERT_PKG_ROOT_DIR = "/usr/local/etc/certificate"

## Define parameter values
INFO_TYPES = (
    ( "id",          "ID of Certificate" ),
    ( "id-desc",     "Description of Certificate ID" ),
    ( "id-path",     "Path of Certificate ID" ),
    ( "id-srv",      "Services of Certificate ID" ),
    ( "id-srv-path", "Path of Services for Certificate ID" ),
)


def dir_path(string):
    if os.path.isdir(string):
        return string
    else:
        raise NotADirectoryError(string)


def createArgParser():
    ## argparse: https://docs.python.org/3/library/argparse.html

    ## Create description
    description = "Output certificate information on DSM (7.x) from related INFO file.\nCopyright (C) 2024 under GPLv2  Matthias \"Maddes\" Bücher"

    ## Build choice/help lists
    ## --> INFO_TYPES
    info_type_choices=[]
    info_type_help="Type of information to output"+os.linesep
    for option in INFO_TYPES:
        info_type_choices.append(option[0])
        info_type_help = "".join((info_type_help, "  {:11} = {}\n".format(option[0], option[1])))

    ## Build Arg Parser
    parser = argparse.ArgumentParser(description=description, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("-t", "--type", metavar="INFO_TYPE", choices=info_type_choices, help=info_type_help, default="id-desc")
    parser.add_argument("-i", "--id", metavar="ID", help="Only output data for this ID if it exists.\nNo more ID prefixes printed, useful for shell scripts.")
    parser.add_argument("-d", "--desc", metavar="DESC", help="Only output data for certificate with this description if it exists.\nNo more ID prefixes printed, useful for shell scripts.")
    parser.add_argument("-s", "--srv", metavar="SRV", help="Only output data for this service if it exists.\nNo more service prefixes printed, useful for shell scripts.")
    #parser.add_argument("-v", "--verbose", action="store_true")

    return parser


def printPrefix(do_print, prefix):
    if do_print:
        print("{}: ".format(prefix), end="")


if __name__ == "__main__":
    ## Check parameters from command line
    ## Notes:
    ## - check Arguments.desc for "is not None", as it must allow empty string for filtering on initial certificate
    Parser = createArgParser()
    Arguments = Parser.parse_args()
    if Arguments.id:
        Arguments.id = Arguments.id.strip()

    ## Determine if any prefixes have to be printed
    PrintIdPrefix = True
    PrintSrvPrefix = True
    #
    if Arguments.id \
    or Arguments.desc is not None:
        PrintIdPrefix = False
    if Arguments.srv:
        PrintSrvPrefix = False

    ## Read INFO file into string
    cert_info_file = open(CERT_INFO_PATH)
    cert_info_data = cert_info_file.read()
    cert_info_file.close()

    ## Parse INFO json string into Python dictionary
    cert_info = json.loads(cert_info_data)
    del cert_info_file, cert_info_data

    ## Process cert info data for output
    for cert_id, cert_def in cert_info.items():
        if Arguments.id \
        and cert_id != Arguments.id:
            continue

        if Arguments.desc is not None \
        and cert_def["desc"] != Arguments.desc:
            continue

        if Arguments.type == "id":
            print(cert_id)
            continue
        elif Arguments.type == "id-desc":
            printPrefix(PrintIdPrefix, cert_id)
            print(cert_def["desc"])
            continue
        elif Arguments.type == "id-path":
            printPrefix(PrintIdPrefix, cert_id)
            print(os.path.join(CERT_SYSTEM_ARCHIVE_DIR, cert_id))
            continue
        elif Arguments.type == "id-srv" \
        or Arguments.type == "id-srv-path":
            for service in cert_def["services"]:
                if Arguments.srv \
                and service["service"] != Arguments.srv:
                    continue

                if Arguments.type == "id-srv":
                    printPrefix(PrintIdPrefix, cert_id)
                    print(service["service"])
                    continue
                elif Arguments.type == "id-srv-path":
                    printPrefix(PrintIdPrefix, cert_id)
                    printPrefix(PrintSrvPrefix, service["service"])
                    if service["isPkg"] is True:
                        cert_root_dir = CERT_PKG_ROOT_DIR
                    else:
                        cert_root_dir = CERT_SYSTEM_ROOT_DIR
                    print(os.path.join(cert_root_dir, service["subscriber"], service["service"]))
                    continue

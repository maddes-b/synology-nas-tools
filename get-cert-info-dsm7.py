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
CERT_DEFAULT_PATH = os.path.join(CERT_SYSTEM_ARCHIVE_DIR, "DEFAULT")
CERT_SERVICES_PATH = os.path.join(CERT_SYSTEM_ARCHIVE_DIR, "SERVICES")
#
CERT_PKG_ROOT_DIR = "/usr/local/etc/certificate"

## Define parameter values
INFO_TYPES = (
    ( "cert-desc",         "Description of Certificate IDs" ),
    ( "cert-id",           "Certificate IDs" ),
    ( "cert-path",         "Path of Certificate IDs" ),
    ( "cert-srv",          "Services IDs of Certificate IDs" ),
    ( "cert-srv-ispkg",    "isPKg Flag of Service IDs of Certificate IDs" ),
    ( "cert-srv-name",     "Display Name of Service IDs of Certificate IDs" ),
    ( "cert-srv-owner",    "Owner of Service IDs of Certificate IDs" ),
    ( "cert-srv-path",     "Certificate Path of Service IDs of Certificate IDs" ),
    ( "cert-srv-subscr",   "Subscriber of Service IDs of Certificate IDs" ),
#
    ( "default",           "Default Certificate ID" ),
#
    ( "srv-id",            "Service IDs" ),
    ( "srv-certpath",      "Certificate Path of Service IDs" ),
    ( "srv-ispkg",         "isPKg Flag of Service IDs" ),
    ( "srv-name",          "Display Name of Service IDs" ),
    ( "srv-owner",         "Owner of Service IDs" ),
    ( "srv-subscr",        "Subscriber of Service IDs" ),
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
        info_type_help = "".join((info_type_help, "  {:15} = {}\n".format(option[0], option[1])))

    ## Build Arg Parser
    parser = argparse.ArgumentParser(description=description, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("-t", "--type", metavar="INFO_TYPE", choices=info_type_choices, help=info_type_help, default="cert-desc")
    parser.add_argument("-c", "--crt", metavar="CERT", help="Only output data for this certificate ID if it exists.\nNo more ID prefixes printed, useful for shell scripts.")
    parser.add_argument("-d", "--dsc", metavar="DESC", help="Only output data for this certificate description if it exists.\nNo more ID prefixes printed, useful for shell scripts.")
    parser.add_argument("-s", "--srv", metavar="SRVC", help="Only output data for this service ID if it exists.\nNo more service prefixes printed, useful for shell scripts.")

    return parser


def printPrefix(do_print, prefix):
    if do_print:
        print("{}: ".format(prefix), end="")


if __name__ == "__main__":
    ## Check parameters from command line
    ## Notes:
    ## - check Arguments.dsc for "is not None", as it must allow empty string for filtering on initial certificate
    Parser = createArgParser()
    Arguments = Parser.parse_args()
    if Arguments.crt:
        Arguments.crt = Arguments.crt.strip()

    ## Determine if any prefixes have to be printed
    PrintIdPrefix = True
    PrintSrvPrefix = True
    #
    if Arguments.crt \
    or Arguments.dsc is not None:
        PrintIdPrefix = False
    if Arguments.srv:
        PrintSrvPrefix = False

    if Arguments.type.startswith("cert"):
        ## /usr/syno/etc/certificate/_archive/INFO

        ## Read INFO file into string
        cert_info_file = open(CERT_INFO_PATH)
        cert_info_data = cert_info_file.read()
        cert_info_file.close()

        ## Parse INFO json string into Python dictionary
        cert_info = json.loads(cert_info_data)
        del cert_info_file, cert_info_data

        ## Process cert info data for output
        for cert_id, cert_def in cert_info.items():
            if Arguments.crt \
            and cert_id != Arguments.crt:
                continue

            if Arguments.dsc is not None \
            and cert_def["desc"] != Arguments.dsc:
                continue

            if Arguments.type == "cert-id":
                print(cert_id)
                continue
            elif Arguments.type == "cert-desc":
                printPrefix(PrintIdPrefix, cert_id)
                print(cert_def["desc"])
                continue
            elif Arguments.type == "cert-path":
                printPrefix(PrintIdPrefix, cert_id)
                print(os.path.join(CERT_SYSTEM_ARCHIVE_DIR, cert_id))
                continue
            elif Arguments.type.startswith("cert-srv"):
                for service in cert_def["services"]:
                    if Arguments.srv \
                    and service["service"] != Arguments.srv:
                        continue

                    if Arguments.type == "cert-srv":
                        printPrefix(PrintIdPrefix, cert_id)
                        print(service["service"])
                        continue
                    elif Arguments.type == "cert-srv-path":
                        printPrefix(PrintIdPrefix, cert_id)
                        printPrefix(PrintSrvPrefix, service["service"])
                        if service["isPkg"] is True:
                            cert_root_dir = CERT_PKG_ROOT_DIR
                        else:
                            cert_root_dir = CERT_SYSTEM_ROOT_DIR
                        print(os.path.join(cert_root_dir, service["subscriber"], service["service"]))
                        continue
                    elif Arguments.type == "cert-srv-ispkg":
                        printPrefix(PrintIdPrefix, cert_id)
                        printPrefix(PrintSrvPrefix, service["service"])
                        print(service["isPkg"])
                        continue
                    elif Arguments.type == "cert-srv-name":
                        printPrefix(PrintIdPrefix, cert_id)
                        printPrefix(PrintSrvPrefix, service["service"])
                        print(service["display_name"])
                        continue
                    elif Arguments.type == "cert-srv-owner":
                        printPrefix(PrintIdPrefix, cert_id)
                        printPrefix(PrintSrvPrefix, service["service"])
                        print(service["owner"])
                        continue
                    elif Arguments.type == "cert-srv-subscr":
                        printPrefix(PrintIdPrefix, cert_id)
                        printPrefix(PrintSrvPrefix, service["service"])
                        print(service["subscriber"])
                        continue
    elif Arguments.type == "default":
        ## Special case: /usr/syno/etc/certificate/_archive/DEFAULT

        ## Read DEFAULT file into string
        cert_default_file = open(CERT_DEFAULT_PATH)
        cert_default_data = cert_default_file.readline().strip('\n')
        cert_default_file.close()

        ## Process cert default data for output
        print(cert_default_data)
    elif Arguments.type.startswith("srv"):
        ## Special case: /usr/syno/etc/certificate/_archive/SERVICES

        ## Read SERVICES file into string
        cert_services_file = open(CERT_SERVICES_PATH)
        cert_services_data = cert_services_file.read()
        cert_services_file.close()

        ## Parse SERVICES json string into Python dictionary
        cert_services = json.loads(cert_services_data)
        del cert_services_file, cert_services_data

        ## Process cert services data for output
        for service in cert_services:
            if Arguments.srv \
            and service["service"] != Arguments.srv:
                continue

            if Arguments.type == "srv-id":
                print(service["service"])
                continue
            elif Arguments.type == "srv-certpath":
                printPrefix(PrintSrvPrefix, service["service"])
                if service["isPkg"] is True:
                    cert_root_dir = CERT_PKG_ROOT_DIR
                else:
                    cert_root_dir = CERT_SYSTEM_ROOT_DIR
                print(os.path.join(cert_root_dir, service["subscriber"], service["service"]))
                continue
            elif Arguments.type == "srv-ispkg":
                printPrefix(PrintSrvPrefix, service["service"])
                print(service["isPkg"])
                continue
            elif Arguments.type == "srv-name":
                printPrefix(PrintSrvPrefix, service["service"])
                print(service["display_name"])
                continue
            elif Arguments.type == "srv-owner":
                printPrefix(PrintSrvPrefix, service["service"])
                print(service["owner"])
                continue
            elif Arguments.type == "srv-subscr":
                printPrefix(PrintSrvPrefix, service["service"])
                print(service["subscriber"])
                continue

#!/usr/bin/ksh

# This file must be sourced in ksh:
#
#   source `which env_parallel.ksh`
#
# after which 'env_parallel' works
#
#
# Copyright (C) 2016
# Ole Tange and Free Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/>
# or write to the Free Software Foundation, Inc., 51 Franklin St,
# Fifth Floor, Boston, MA 02110-1301 USA

# Supports env of 127426 bytes

env_parallel() {
    # env_parallel.ksh

    # Get the --env variables if set
    # --env _ should be ignored
    # and convert  a b c  to (a|b|c)
    # If --env not set: Match everything (.*)
    _grep_REGEXP="$(
        perl -e 'for(@ARGV){
                /^_$/ and $next_is_env = 0;
                $next_is_env and push @envvar, split/,/, $_;
                $next_is_env=/^--env$/;
            }
            $vars = join "|",map { quotemeta $_ } @envvar;
            print $vars ? "($vars)" : "(.*)";
            ' -- "$@"
    )"
    # Deal with --env _
    _ignore_UNDERSCORE="$(
        perl -e 'for(@ARGV){
                $next_is_env and push @envvar, split/,/, $_;
                $next_is_env=/^--env$/;
            }
            $underscore = grep { /^_$/ } @envvar;
            print $underscore ? "grep -vf $ENV{HOME}/.parallel/ignored_vars" : "cat";
            ' -- "$@"
    )"

    # Grep alias names
    _alias_NAMES="$(alias | perl -pe 's/=.*//' |
        egrep "^${_grep_REGEXP}\$" | $_ignore_UNDERSCORE)"
    _list_alias_BODIES="alias $_alias_NAMES | perl -pe 's/^/alias /'"
    if [[ "$_alias_NAMES" = "" ]] ; then
	# no aliases selected
	_list_alias_BODIES="true"
    fi
    unset _alias_NAMES

    # Grep function names
    _function_NAMES="$(typeset +p -f | perl -pe 's/\(\).*//' |
        egrep "^${_grep_REGEXP}\$" | $_ignore_UNDERSCORE)"
    _list_function_BODIES="typeset -f $_function_NAMES"
    if [[ "$_function_NAMES" = "" ]] ; then
	# no functions selected
	_list_function_BODIES="true"
    fi
    unset _function_NAMES

    # Grep variable names
    _variable_NAMES="$(typeset +p | perl -pe 's/^typeset .. //' |
        egrep "^${_grep_REGEXP}\$" | $_ignore_UNDERSCORE |
        egrep -v '^(PIPESTATUS)$')"
    _list_variable_VALUES="typeset -p $_variable_NAMES"
    if [[ "$_variable_NAMES" = "" ]] ; then
	# no variables selected
	_list_variable_VALUES="true"
    fi
    unset _variable_NAMES

    # eval is needed for aliases - cannot explain why
    export PARALLEL_ENV="$(
        eval $_list_alias_BODIES;
        $_list_variable_VALUES;
        $_list_function_BODIES)";
    unset _list_alias_BODIES
    unset _list_variable_VALUES
    unset _list_function_BODIES
    `which parallel` "$@";
    unset PARALLEL_ENV;
}

# _env_parallel() {
#   # env_parallel.ksh
#   export PARALLEL_ENV="$(alias | perl -pe 's/^/alias /';typeset -p|egrep -v 'typeset( -i)? -r|PIPESTATUS';typeset -f)";
#   `which parallel` "$@";
#   unset PARALLEL_ENV;
# }

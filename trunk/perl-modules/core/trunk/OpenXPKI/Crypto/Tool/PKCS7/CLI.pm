## OpenXPKI::Crypto::Tool::PKCS7::CLI
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
## $Revision$
package OpenXPKI::Crypto::Tool::PKCS7::CLI;
use base qw( OpenXPKI::Crypto::CLI );

use strict;
use warnings;
use English;
use Class::Std;

use OpenXPKI::Debug 'OpenXPKI::Crypto::Tool::PKCS7::CLI';

sub error_ispresent {
    my $self = shift;
    my $ident = ident $self;
    my $stderr = shift;

    if ($stderr =~ m{ [eE]rror }xms) { # TODO: check more possible error output
        return 1;
    }
    else {
        return 0;
    }
}
1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::PKCS7::CLI

=head1 Desription

This module implements the handling of the openca-scep shell. It is a child
of OpenXPKI::Crypto::CLI. 

=head1 Functions

=head2 error_ispresent

Checks whether there is an error in the STDERR output.

=head1 See also:

OpenXPKI::Crypto::CLI
# OpenXPKI::Server::Workflow::Condition::SignedUsingOriginalCertOrSelfSigned.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$
package OpenXPKI::Server::Workflow::Condition::SignedUsingOriginalCertOrSelfSigned;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug 'OpenXPKI::Server::API::Workflow::Condition::SignedUsingOriginalCertOrSelfSigned';
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::X509;

use English;

use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context   = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)
    my $scep_server = $context->param('server');
    my $current_identifier = $context->param('current_identifier');
    my $pki_realm = CTX('session')->get_pki_realm(); 

    ##! 16: 'my condition name: ' . $self->name()
    my $negate = 0;
    if ($self->name() eq 'self_signed') {
        $negate = 1;
    }

     my $pkcs7 = $context->param('pkcs7_content');
     $pkcs7 = "-----BEGIN PKCS7-----\n" . $pkcs7 . "-----END PKCS7-----\n";

     ##! 32: 'pkcs7: ' . $pkcs7
     my $scep_token = CTX('pki_realm')->{$pki_realm}->{scep}->{id}->{$scep_server}->{crypto}; 
     my $signer_cert = $scep_token->command({
         COMMAND => 'get_signer_cert',
         PKCS7   => $pkcs7,
    });
    ##! 64: 'signer_cert: ' . $signer_cert

    my $tm = OpenXPKI::Crypto::TokenManager->new();
    my $default_token = $tm->get_token(
        TYPE      => 'DEFAULT',
        PKI_REALM => $pki_realm,
    );

    my $x509 = OpenXPKI::Crypto::X509->new(
        TOKEN => $default_token,
        DATA  => $signer_cert,
    );

    my $signer_cert_identifier = $x509->get_identifier();
    ##! 16: 'signer cert identifier: ' . $signer_cert_identifier

    if (!defined $signer_cert_identifier || $signer_cert_identifier eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SIGNEDUSINGORIGINALCERTORSELFSIGNED_COULD_NOT_ESTABLISH_SIGNER_CERT_ID',
        );
    }

    if ($negate == 1) { # we are asked if this is self signed
        ##! 16: 'negate=1'
        if ($signer_cert_identifier eq $current_identifier) {
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SIGNEDUSINGORIGINALCERTORSELFSIGNED_SIGNED_USING_ORIGINAL_CERT');
        }
    }
    else {
        ##! 16: 'negate=0'
        if ($signer_cert_identifier ne $current_identifier) {
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SIGNEDUSINGORIGINALCERTORSELFSIGNED_SELF_SIGNED');
        }
    }
    ##! 16: 'end'
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::SignedUsingOriginalCertOrSelfSigned

=head1 SYNOPSIS

<action name="do_something">
  <condition name="signed_using_original_cert"
             class="OpenXPKI::Server::Workflow::Condition::SignedUsingOriginalCertOrSelfSigned">
  </condition>
</action>

=head1 DESCRIPTION

This condition checks whether a renewal SCEP request (PKCS#7) is signed
with the selected original, currently valid certificate.
If the condition name is "signed_using_original_cert", it returns
true if the signature is valid and the signature key matches the
original certificate key.
TODO -- we can check against the serial reported by openca-sv verify,
is that enough???
If the condition name is "self_signed", the condition works in exactly
the opposite way.
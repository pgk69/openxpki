# OpenXPKI::Server::Workflow::Activity::NICE::IssueCertificate
# Written by Oliver Welter for the OpenXPKI Project 2011
# Copyright (c) 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::NICE::IssueCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use English;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use OpenXPKI::Server::Workflow::NICE::Factory;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;

    my $context = $workflow->context();
    
    ##! 32: 'context: ' . Dumper( $context )
    
    my $nice_backend = OpenXPKI::Server::Workflow::NICE::Factory->getHandler( $self );
    
    # Load the CSR indicated by the context parameter from the database 
	my $csr_serial = $context->param( 'csr_serial' );
		
    ##! 32: 'load csr from db: ' . $csr_serial 	
    # get a fresh view of the database
    CTX('dbi_backend')->commit();

    my $csr = CTX('dbi_backend')->first(
        TABLE   => 'CSR',
        KEY => $csr_serial,        
    );
    
    ##! 64: 'csr: ' . Dumper $csr   
    if (! defined $csr) {
	   OpenXPKI::Exception->throw(
	       message => 'I18N_OPENXPKI_SERVER_NICE_CSR_NOT_FOUND_IN_DATABASE',
	       params => { csr_serial => $csr_serial }
       );
    }

    if ($csr->{TYPE} ne 'pkcs10' && $csr->{TYPE} ne 'spkac') {
	   OpenXPKI::Exception->throw(
	       message => 'I18N_OPENXPKI_SERVER_NICE_CSR_WRONG_TYPE',
	       params => { EXPECTED => 'pkcs10/spkac', TYPE => $csr->{TYPE} },
        );
    }   

    CTX('log')->log(
        MESSAGE  => "start cert issue for serial $csr_serial, workflow " . $workflow->id,
        PRIORITY => 'info',
        FACILITY => [ 'application', 'audit' ]
    );

    my $set_context;
    eval {
        $set_context = $nice_backend->issueCertificate( $csr );
    };
    
    if ($EVAL_ERROR) {
        
        # Catch exception as "pause" if configured
        if ($self->param('pause_on_error')) {            
            CTX('log')->log(
                MESSAGE  => "NICE issueCertificate failed but pause_on_error is requested ",
                PRIORITY => 'warn',
                FACILITY => [ 'application' ]
            );
            $self->pause('I18N_OPENXPKI_UI_PAUSED_CERTSIGN_TOKEN_SIGNING_FAILED');
        } 
        
        if (my $exc = OpenXPKI::Exception->caught()) {
            $exc->rethrow();
        } else {
            OpenXPKI::Exception->throw( message => $EVAL_ERROR );
        }
    }

    ##! 64: 'Setting Context ' . Dumper $set_context      
    foreach my $key (keys %{$set_context} ) {
        my $value = $set_context->{$key};
        ##! 64: "Set key: $key to value $value";
        $context->param( $key, $value );
    }

    ##! 64: 'Context after issue ' .  Dumper $context
    
    # Record the certificate owner information, see
    # https://github.com/openxpki/openxpki/issues/183   
    my $owner = $self->param('cert_owner');
    
    ##! 64: 'Params ' . Dumper $self->param()
    ##! 32: 'Owner ' . $owner 
    if ($owner) {
        CTX('dbi_backend')->insert(
            TABLE => 'CERTIFICATE_ATTRIBUTES',
            HASH => {
                IDENTIFIER => $set_context->{cert_identifier},
                ATTRIBUTE_KEY => 'system_cert_owner',
                ATTRIBUTE_VALUE => $owner,
            }
        );
    }
    
    		
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::IssueCertificate;

=head1 Description

Loads the certificate signing request referenced by the csr_serial context
parameter from the database and hands it to the configured NICE backend.

Note that it highly depends on the implementation what properties are taken from
the pkcs10 container and what can be overridden by other means.
The activity allows request types spkac and pkcs10 - you need to adjust this 
if you use other formats.
See documentation of the used backend for details.   

See OpenXPKI::Server::Workflow::NICE::issueCertificate for details

=head1 Parameters

=head2 Input

=over

=item csr_serial - the serial number of the certificate signing request

=back

=head2 Output

=over

=item cert_identifier - the identifier of the issued certificate or I<pending>

=back

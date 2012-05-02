package RUM::Platform::Cluster;

=head1 NAME

RUM::Platform::Cluster - Abstract base class for a platform that runs on a cluster

=head1 SYNOPSIS

=head1 DESCRIPTION

This attempts to provide an abstraction over platforms that are based
on a cluster. There is currently only one implementation:
L<RUM::Platform::SGE>.

=head1 OBJECT METHODS

=over 4

=cut

use strict;
use warnings;

use Carp;

use RUM::WorkflowRunner;
use RUM::Workflows;
use RUM::Logging;

use base 'RUM::Platform';

our $log = RUM::Logging->get_logger;

our $CLUSTER_CHECK_INTERVAL = 30;

=item preprocess

Submits the preprocessing task.

=cut

sub preprocess {
    my ($self) = @_;
    $self->say("Submitting preprocessing task");
    $self->submit_preproc;
}

=item chunk_workflow($chunk)

Return the RUM::Workflow for the given chunk.

=cut

sub chunk_workflow {
    my ($self, $chunk) = @_;
    return RUM::Workflows->chunk_workflow($self->config, $chunk);
}

=item postprocessing_workflow($chunk)

Return the postprocessing RUM::Workflow.

=cut

sub postprocessing_workflow {
    my ($self, $chunk) = @_;
    my $config = $self->config;
    my $workflow = RUM::Workflows->postprocessing_workflow($config);
}

=item process($chunk)

Submits the processing tasks, and periodically polls them to check
their status, attempting to restart any tasks that don't seem to be
running. If chunk is provided, I'll just do that chunk.

=cut

sub process {
    my ($self, $chunk) = @_;

    if ($chunk) {
        $self->say("Submitting chunk $chunk");
        $self->submit_proc($chunk);
        return;
    }

    # Build a list of tasks, one for each chunk, that bundles together
    # the chunk number, configuration, workflow, and workflow runner.
    my @tasks;
    for my $chunk ($self->chunk_nums) {
        my $workflow = $self->chunk_workflow($chunk);
        my $run = sub { $self->submit_proc($chunk) };
        my $runner = RUM::WorkflowRunner->new($workflow, $run);
        push @tasks, {
            chunk => $chunk,
            workflow => $workflow,
            runner => $runner
        };
    }

    my @results;

    # First submit all the chunks as one array job
    $self->submit_proc;
    
    while (1) {

        # Counter of tasks that are still running
        my $still_running = 0;

        # Refresh the cluster's status so that calls to proc_ok will
        # return the latest status
        $self->update_status;

        for my $t (@tasks) {

            my ($workflow, $chunk, $runner) = @$t{qw(workflow chunk runner)};

            # If the state of the workflow indicates that it's
            # complete (based on the files that exist), we can
            # consider it done.
            if ($workflow->is_complete) {
                $log->debug("Chunk $chunk is done");
                $results[$chunk] = 1;
            }

            # If the job appears to be running or waiting on the
            # cluster, increment $still_running so we wait for it to
            # finish.
            elsif ($self->proc_ok($chunk)) {
                $log->debug("Looks like chunk $chunk is running or waiting");
                $still_running++;
            }

            # Otherwise the task is not done and it's not running, so
            # submit it again unless we've exceeded the restart limit.
            elsif ($runner->run) {
                $log->error("Chunk $chunk is not queued; started it");
                $still_running++;
            }
            else {
                $log->error("Restarted $chunk too many times; giving up");
                $results[$chunk] = 0;
            }
        }
        $log->debug("$still_running chunks are still running");
        last unless $still_running;
        sleep $CLUSTER_CHECK_INTERVAL;
    }
    return \@results;
    
}

=item postprocess

Submits the postprocessing task, and periodically polls it to check on
its status, restarting it if it seems to have failed.

=cut

sub postprocess {
    my ($self) = @_;

    my $workflow = $self->postprocessing_workflow;
    my $run = sub { $self->submit_postproc };
    my $runner = RUM::WorkflowRunner->new($workflow, $run);

    $runner->run;

    while (1) {

        sleep $CLUSTER_CHECK_INTERVAL;
        $self->update_status;

        if ($workflow->is_complete) {
            $log->debug("Postprocessing is done");
            return 1;
        }

        elsif ($self->postproc_ok) {
            $log->debug("Looks like postprocessing is running or waiting");
        }

        elsif ($runner->run) {
            $log->error("Postprocessing is not queued; starting it");
        }
        else {
            $log->error("Restarted postprocessing too many times; giving up");
            $log->debug("Postprocessing has failed");
            return 0;
        }

        $log->debug("Postprocessing is still running");

        sleep $CLUSTER_CHECK_INTERVAL;
    }

}

=back

=head2 Abstract Methods

=over 4

=item submit_preproc

=item submit_proc

=item submit_postproc

Subclasses must implement these methods to submit the respective
tasks.

submit_preproc and submit_postproc will be called with no arguments.

submit_proc may be called with either no arguments or an optional
$chunk argument. If called with no arguments, the implementation
should submit all chunks. If called with a $chunk argument, the
implementation should submit only the job for that chunk.

=item update_status

A subclass should implement this so that it refreshes whatever data
structure it uses to store the status of its jobs.

=item proc_ok

=item postproc_ok

A subclass should implement these methods so that they return a true
value if the processing or postprocessing phase (respectively) is in
an 'ok' state, where it is either running or waiting to be run.

=cut

sub submit_preproc { croak "submit_preproc not implemented" }
sub submit_proc { croak "submit_proc not implemented" }
sub submit_postproc { croak "submit_postproc not implemented" }
sub update_status { croak "update_status not implemented" }
sub proc_ok { croak "proc_ok not implemented" }
sub postproc_ok { croak "postproc_ok not implemented" }


1;

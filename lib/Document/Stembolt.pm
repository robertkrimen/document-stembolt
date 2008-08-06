package Document::Stembolt;

use warnings;
use strict;

=head1 NAME

Document::Stembolt -

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use Moose;

use Document::Stembolt::Content;

=head1 AUTHOR

Robert Krimen, C<< <rkrimen at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-document-stembolt at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Document-Stembolt>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Document::Stembolt


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Document-Stembolt>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Document-Stembolt>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Document-Stembolt>

=item * Search CPAN

L<http://search.cpan.org/dist/Document-Stembolt>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Robert Krimen, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Document::Stembolt

__END__

use YAML::Tiny;
use DateTime;
use DateTimeX::Easy;
use Data::UUID;
use Carp::Clan;
use HTML::TreeBuilder::Select;
use MooseX::Types::Path::Class qw/Dir File/;

has file => qw/is ro coerce 1 required 1/, isa => File;
#has _content => qw/is ro required 1 lazy 1/, default => sub {
#    return YAML::Tiny->read(shift->file);
#};
has preamble => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    $self->_parse;
    return $self->{preamble};
};
has appendix => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    $self->_parse;
    return $self->{appendix};
};
has content => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    $self->_parse;
    return $self->{content};
};
has excerpt => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    $self->_parse;
    return $self->{appendix};
};


sub write {
    my $class = shift;
    local %_ = @_;

    my $post = $_{post};
    my $path = $_{path};

    my $file;
    if ($_{file}) {
        $file = $_{file};
    }
    elsif ($_{dir}) {
        $file = $_{dir}->file("$path");
    }

    $file->parent->mkpath unless -d $file->parent;

    my $content = YAML::Tiny->new;
    if ($post) {
        $content->[0] = {
            %{ $post->appendix },
            (map { $_ => $post->$_ } qw/title path uuid/),
            idtime => $post->idtime->strftime("\%F \%T \%z"),
        };
        my $openw = $file->openw;
        $openw->print($post->preamble);
        $openw->print($content->write_string);
        $openw->print("---\n");
        $openw->print($post->content);
    }
    else {
        my $content = YAML::Tiny->new;
        my $idtime = DateTime->now(qw/time_zone UTC/); # "%FT%T %Z"
        $content->[0] = { # Header, meta, ..., whatever
            path => $path,
            title => undef,
            idtime => $idtime->strftime("%F %T %z"),
            uuid => Data::UUID->new->create_str,
        };
        $content->[1] = undef;
        $content->write($file);
    }

    return $file;
}

sub exists {
    my $self = shift;
    return -f $self->file;
}

sub _parse {
    my $self = shift;

    my @line = $self->file->slurp;
    shift @line while ! $line[0];

    croak "Document is empty" unless @line;
    my @preamble;
    push @preamble, shift @line while @line && $line[0] !~ m/^\s*---\s*$/;
    croak "Unrecognized document: $line[0]" unless @line && $line[0] =~ m/^\s*---\s*$/;
    my $preamble = $self->{preamble} = join "", @preamble;

    shift @line;
    my @appendix;
    push @appendix, shift @line while @line && $line[0] !~ m/^\s*---\s*$/;
    my $appendix = YAML::Tiny->read_string(join "", @appendix);

    shift @line;
    my @content = @line;
    my $content = join "", @content;
    $content = "" unless @content;

    $self->{appendix} = $appendix->[0];
#    for (qw/idtime udtime/) {
#        $self->{appendix}->{$_} = DateTimeX::Easy->new($self->{appendix}->{$_}) if $self->{appendix}->{$_};
#    }
    $self->{content} = \$content;

    my $HTML = 1;
    if ($HTML) {
        my $tree = HTML::TreeBuilder->new_from_content($content);
        my ($excerpt) = $tree->select("div.excerpt");
        ($excerpt) = $tree->select("span.excerpt") unless ($excerpt);

        if ($excerpt) {
            $self->{excerpt} = $excerpt->as_text;
        }
        else {
            my $text = $tree->as_text;
            my @words = $text =~ m/\b(\w+)\b/g;
            @words = @words[0 .. 49] if @words > 49;
            $self->{appendix}->{excerpt} = $self->{excerpt} = join " ", @words;
        }
    }
}

1;



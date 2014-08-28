package Mojolicious::Plugin::AssetPack::Preprocessor::Sass;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Sass - Preprocessor for .sass files

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Sass> is a preprocessor for
C<.sass> files.

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use Mojo::Util qw( slurp md5_sum );
use File::Basename 'dirname';
use File::Spec::Functions 'catfile';
use File::Which ();

=head1 ATTRIBUTES

=head2 executable

  $path = $self->executable;

Holds the path to the "sass" executable, if it could be found.

=cut

has executable => File::Which::which('sass');

=head1 METHODS

=head2 checksum

Returns the checksum for the given C<$text>, but also checks for any
C<@import> statements and includes those files in the checksum.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub checksum {
  my ($self, $text, $path) = @_;
  my $ext = $path =~ /\.(s[ac]ss)$/ ? $1 : $self->_extension;
  my $dir = dirname $path;
  my $re = qr{ \@import \s+ (["']) (.*?) \1 }x;
  my @checksum = md5_sum $$text;

  while ($$text =~ /$re/gs) {
    my $file = $2;
    if (-r "$dir/$file.$ext") {
      push @checksum, md5_sum slurp catfile $dir, "$file.$ext";
    }
    elsif (-r "$dir/_$file.$ext") {
      push @checksum, md5_sum slurp catfile $dir, "_$file.$ext";
    }
  }

  return Mojo::Util::md5_sum(join '', @checksum);
}

=head2 process

This method use "sass" to process C<$text>.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my @cmd = ( $self->executable, '--stdin' );

  push @cmd, '-I' => dirname $path;
  push @cmd, qw( -t compressed) if $assetpack->minify;

  Mojolicious::Plugin::AssetPack::Preprocessors->_run(\@cmd, $text, $text);

  return $self;
}

sub _extension { 'sass' }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
package Mojolicious::Plugin::AssetPack::Pipe::Reloader;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';
use Mojo::Loader ();

has _files => sub { +{} };

sub before_process {
  my ($self, $assets) = @_;
  $self->_files->{$_} = 1 for map { ($_->path, @{$_->{dependencies} || []}) } @$assets;
}

sub new {
  my $self = shift->SUPER::new(@_);

  push @{$self->assetpack->store->classes}, __PACKAGE__;
  $self->assetpack->{lazy} = 1;
  $self->assetpack->process('reloader.js' => 'reloader.js');
  $self->_add_route;
  $self->_start_watching;
  $self;
}

sub process { }

sub _add_route {
  shift->app->routes->websocket('/mojo-assetpack-reloader-ws')->to(
    cb => sub {
      my $c = shift;
      my $cb = sub { $c->finish; };
      $c->inactivity_timeout(3600);
      $c->app->plugins->on(assets_changed => $cb);
      $c->on(finish => sub { shift->app->plugins->unsubscribe(assets_changed => $cb); });
    }
  )->name('mojo-assetpack-reloader-ws');
}

sub _start_watching {
  my $self  = shift;
  my $app   = $self->app;
  my $files = $self->_files;
  my $cache = {};

  Mojo::IOLoop->recurring(
    $ENV{MOJO_ASSETPACK_CHECK_INTERVAL} || 0.5,
    sub {
      my @changed;
      for my $file (sort keys %$files) {
        my ($size, $mtime) = (stat $file)[7, 9];
        next unless defined $mtime;
        my $stats = $cache->{$file} ||= [$^T, $size];
        next if $mtime <= $stats->[0] && $size == $stats->[1];
        @$stats = ($mtime, $size);
        push @changed, $file;
      }

      $app->plugins->emit(assets_changed => \@changed) if @changed;
    }
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Reloader - Automatically reload assets in browser

=head1 SYNOPSIS

=head2 Application

  $app->plugin(AssetPack => {pipes => ["Reloader"]);

=head2 Template

  %= asset "reloader.js" if app->mode eq "development"

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::Reloader> is a pipe which will create
an asset called "reloader.js". This asset will automatically reload the page in
the browser when one of the assets change on disk. This is done without the
need of L<morbo|Mojo::Server::Morbo>.

This feature is EXPERIMENTAL, UNSTABLE and only meant to be used while
developing.

=head1 METHODS

=head2 before_process

See L<Mojolicious::Plugin::AssetPack::Pipe/before_process>.

=head2 new

Used to add a special "reloader.js" asset and a
"/mojo-assetpack-reloader-ws" WebSocket endpoint.

=head2 process

This method does nothing.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut

__DATA__
@@ reloader.js
window.addEventListener("load", function(e) {
  var script   = document.querySelector('script[src$="/reloader.js"]');
  var reloader = function() {
    var socket = new WebSocket(script.src.replace(/^http/, "ws").replace(/\basset.*/, "mojo-assetpack-reloader-ws"));
    socket.onopen = function() { console.log("[AssetPack] Reloader is active."); };
    socket.onclose = function() { return location = location.href; };
  };
  reloader();
});

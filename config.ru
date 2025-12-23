# frozen_string_literal: true

require 'faye'
require_relative 'require_app'
require_app

use Faye::RackAdapter, mount: '/faye', timeout: 20
run Eventure::App.freeze.app

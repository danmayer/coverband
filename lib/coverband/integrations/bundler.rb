# frozen_string_literal: true

module BundlerEagerLoad
  def require(*groups)
    Coverband.eager_loading_coverage { super }
  end
end
Bundler.singleton_class.prepend BundlerEagerLoad

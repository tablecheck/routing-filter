module ActionDispatchJourneyRouterWithFiltering
  if ActionPack.gem_version >= Gem::Version.new('8.1')
    # Rails 8.1 removed Journey::Router#find_routes; matching happens in #recognize,
    # which rewrites path_info for mounted (non-anchored) routes before yielding.
    # Only restore the original path for anchored routes so mount rewriting survives.
    def recognize(req, &block)
      path = req.path_info
      original_path = path.dup
      filter_parameters = {}

      @routes.filters.run(:around_recognize, path, req) { filter_parameters }

      return super if filter_parameters.empty? && path == original_path

      super(req) do |route, parameters|
        req.path_info = original_path if route.path.anchored
        yield(route, parameters.merge(filter_parameters))
      end
    end
  else
    def find_routes(env)
      path = env.is_a?(Hash) ? env['PATH_INFO'] : env.path_info
      filter_parameters = {}
      original_path = path.dup

      @routes.filters.run(:around_recognize, path, env) do
        filter_parameters
      end

      super(env) do |match, parameters, route|
        parameters = parameters.merge(filter_parameters)

        if env.is_a?(Hash)
          env['PATH_INFO'] = original_path
        else
          env.path_info = original_path
        end

        yield [match, parameters, route]
      end
    end
  end
end

ActionDispatch::Journey::Router.send(:prepend, ActionDispatchJourneyRouterWithFiltering)

require 'decorators/include_decorator'

module VCAP::CloudController
  class IncludeSpaceDecorator < IncludeDecorator
    class << self
      def association_name
        'space'
      end

      def association_class
        Space
      end

      def presenter
        Presenters::V3::SpacePresenter
      end
    end
  end

  IncludeDecoratorRegistry.register(IncludeSpaceDecorator)
end
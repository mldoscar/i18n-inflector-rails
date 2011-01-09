# encoding: utf-8
#
# Author::    Paweł Wilk (mailto:pw@gnu.org)
# Copyright:: (c) 2010 by Paweł Wilk
# License::   This program is licensed under the terms of {file:LGPL-LICENSE GNU Lesser General Public License} or {file:COPYING Ruby License}.
# 
# This file contains I18n::Backend::Inflector::Rails module,
# which extends ActionView::Helpers::TranslationHelper
# by adding the ability to interpolate patterns containing
# inflection tokens defined in translation data.

module I18n
  module Inflector
    module Rails
  
      # This module contains instance methods for ActionController.
      module InstanceMethods
  
        # This method calls the class method {I18n::Inflector::Rails::ClassMethods#i18n_inflector_methods}
        def i18n_inflector_methods
          self.class.i18n_inflector_methods
        end
  
      end # instance methods
  
      # This module contains class methods for ActionController.
      module ClassMethods
  
        # This method reads the internal Hash +i18n_inflector_methods+ containing registered
        # inflection methods and the assigned kinds. It also reads any methods
        # assignments that were defined earlier in the inheritance path and
        # merges them with current results; the most current entries will
        # override the entries defined before.
        # 
        # @api public
        # @return [Hash] the Hash containing assignments made by using {inflection_method}
        def i18n_inflector_methods
          prev = superclass.respond_to?(:i18n_inflector_methods) ? superclass.i18n_inflector_methods : {}
          return @i18n_inflector_methods.nil? ? prev : prev.merge(@i18n_inflector_methods)
        end
  
        # This method allows to assign methods (typically attribute readers)
        # to inflection kinds that are defined in translation files and
        # supported by {I18n::Inflector} module. Methods registered like that
        # will be tracked when {translate} is used and their returning values will be
        # passed as inflection options along with assigned kinds.
        # 
        # @api public
        # @param [Hash] assignment the methods and inflection kinds assigned to them
        # @yield [method, kind, value, caller] optional block that will be executed
        #   each time the registered method is called. Its result will replace
        #   the original returning value of the method that is assigned to a kind
        # @yieldparam [Symbol] method the name of an assigned method
        # @yieldparam [Symbol] kind the name of an inflection kind assigned to that +method+
        # @yieldparam [Object] value the original result of calling the +method+ that will be assigned to a +kind+ as a token
        # @yieldparam [Object] caller the object that made a call to {translate} method
        # @yieldreturn [String] the new +value+ (token name) that will be assigned to a +kind+
        def inflection_method(assignment, &block)
          if (assignment.nil? || !assignment.is_a?(Hash) || assignment.empty?)
            raise I18n::Inflector::Rails::BadInflectionMethod.new(assignment)
          end
          @i18n_inflector_methods ||= {}
          assignment.each_pair do |k,v|
            k = k.to_s
            v = v.to_s
            if (k.empty? || v.empty?)
              raise I18n::Inflector::Rails::BadInflectionMethod.new("#{k.inspect} => #{v.inspect}")
            end
            k = k.to_sym
            @i18n_inflector_methods[k]      ||= {}
            @i18n_inflector_methods[k][:kind] = v.to_sym
            @i18n_inflector_methods[k][:proc] = block
          end
        end
        alias_method :inflection_methods, :inflection_method
  
      end # class methods
  
      # This module contains a version of {translate} method that
      # tries to use +i18n_inflector_methods+ available in the current context.
      # The method from this module will wrap the
      # {ActionView::Helpers::TranslationHelper#translate} method.
      module InflectedTranslate
  
        # This method tries to feed itself with the data coming
        # from +i18n_inflector_methods+ available in the current context.
        # The data from the last method should contain options
        # of inflection pairs (<tt>kind => value</tt>) that will
        # be passed to {I18n::Backend::Inflector#translate} through
        # {ActionView::Helpers::TranslationHelper#translate}.
        # 
        # @api public
        # @param [String] key translation key
        # @param [Hash] options a set of options to pass to the
        #   translation routines
        # @return [String] the translated string with inflection patterns
        #   interpolated
        def translate(*args)
          return super unless respond_to?(:i18n_inflector_methods)
          test_locale = args.last.is_a?(Hash) ? args.last[:locale] : nil
          test_locale ||= I18n.locale
          return super unless I18n::Inflector.locale?(test_locale)
  
          # collect inflection variables that are present in this context
          subopts = t_prepare_inflection_options
  
          # jump to original translate if no variables are present
          return super if subopts.empty?
  
          options = args.last.is_a?(Hash) ? args.pop : {}
          args.push subopts.merge(options)
          super
        end
  
        protected
  
        # This method tries to read +i18n_inflector_methods+ available in the current context.
        # 
        # @return [Hash] the inflection options (<tt>kind => value</tt>)
        def t_prepare_inflection_options
          subopts = {}
          i18n_inflector_methods.each_pair do |m, obj|
            next unless respond_to?(m)
            value = method(m).call
            proca = obj[:proc]
            kind  = obj[:kind]
            value = proca.call(m, kind, value, self) unless proca.nil?
            subopts[kind] = value.to_s
          end
          return subopts
        end
        
      end # Translate
  
    end
  end
end
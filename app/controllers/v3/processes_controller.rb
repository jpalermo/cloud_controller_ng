require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/process_presenter'
require 'presenters/v3/process_stats_presenter'
require 'cloud_controller/paging/pagination_options'
require 'actions/process_create'
require 'actions/process_delete'
require 'fetchers/process_list_fetcher'
require 'fetchers/process_fetcher'
require 'actions/process_scale'
require 'actions/process_terminate'
require 'actions/process_update'
require 'messages/process_scale_message'
require 'messages/process_create_message'
require 'messages/process_update_message'
require 'messages/processes_list_message'
require 'controllers/v3/mixins/app_sub_resource'
require 'cloud_controller/strategies/non_manifest_strategy'

class ProcessesController < ApplicationController
  include AppSubResource

  before_action :find_process_and_space, except: :index
  before_action :ensure_can_write, only: %i(update terminate scale)

  def index
    message = ProcessesListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    if app_nested?
      app, dataset = ProcessListFetcher.new(message).fetch_for_app
      app_not_found! unless app && permission_queryer.can_read_from_space?(app.space.guid, app.organization.guid)
    else
      dataset = if permission_queryer.can_read_globally?
                  ProcessListFetcher.new(message).fetch_all
                else
                  ProcessListFetcher.new(message).fetch_for_spaces(space_guids: permission_queryer.readable_space_guids)
                end
    end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ProcessPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: base_url(resource: 'processes'),
      message: message
    )
  end

  def show
    # TODO
    render status: :ok, json: Presenters::V3::ProcessPresenter.new(@process, show_secrets: permission_queryer.can_read_secrets_in_space?(@space.guid, @space.organization.guid))
  end

  def create
    message = ProcessCreateMessage.new(unmunged_body)
    unprocessable!(message.errors.full_messages) unless message.valid?

    app = AppModel.first(guid: message.app_guid)
    app_not_found! unless app && permission_queryer.can_read_from_space?(app.space.guid, app.organization.guid)

    process_attrs = {}
    process_attrs[:type] = message.type
    process_attrs[:revision_guid] = message.revision_guid
    process_attrs[:guid] = SecureRandom.uuid
    process_attrs[:state] = app.desired_state

    process = ProcessCreate.new(user_audit_info).create(app, process_attrs)

    render status: :ok, json: Presenters::V3::ProcessPresenter.new(process)
  rescue ProcessCreate::InvalidProcess => e
    unprocessable!(e.message)
  end

  def update
    message = ProcessUpdateMessage.new(unmunged_body)
    unprocessable!(message.errors.full_messages) unless message.valid?

    ProcessUpdate.new(user_audit_info).update(@process, message, NonManifestStrategy)

    render status: :ok, json: Presenters::V3::ProcessPresenter.new(@process)
  rescue ProcessUpdate::InvalidProcess => e
    unprocessable!(e.message)
  end

  def terminate
    ProcessTerminate.new(user_audit_info, @process, hashed_params[:index].to_i).terminate

    head :no_content
  rescue ProcessTerminate::InstanceNotFound
    resource_not_found!(:instance)
  end

  def scale
    FeatureFlag.raise_unless_enabled!(:app_scaling)

    message = ProcessScaleMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) if message.invalid?

    ProcessScale.new(user_audit_info, @process, message).scale

    render status: :accepted, json: Presenters::V3::ProcessPresenter.new(@process)
  rescue ProcessScale::InvalidProcess => e
    unprocessable!(e.message)
  end

  def stats
    process_stats = instances_reporters.stats_for_app(@process)

    render status: :ok, json: Presenters::V3::ProcessStatsPresenter.new(@process.type, process_stats)
  end

  private

  def find_process_and_space
    if app_nested?
      @process, app, @space, org = ProcessFetcher.fetch_for_app_by_type(app_guid: hashed_params[:app_guid], process_type: hashed_params[:type])
      app_not_found! unless app && permission_queryer.can_read_from_space?(@space.guid, org.guid)
      process_not_found! unless @process
    else
      @process, @space, org = ProcessFetcher.fetch(process_guid: hashed_params[:process_guid])
      process_not_found! unless @process && permission_queryer.can_read_from_space?(@space.guid, org.guid)
    end
  end

  def ensure_can_write
    unauthorized! unless permission_queryer.can_write_to_space?(@space.guid)
  end

  def process_not_found!
    resource_not_found!(:process)
  end

  def instances_reporters
    CloudController::DependencyLocator.instance.instances_reporters
  end
end

require 'actions/organization_create'
require 'actions/organization_update'
require 'actions/organization_delete'
require 'actions/set_default_isolation_segment'
require 'controllers/v3/mixins/sub_resource'
require 'fetchers/org_list_fetcher'
require 'messages/organization_update_message'
require 'messages/organization_create_message'
require 'messages/orgs_default_iso_seg_update_message'
require 'messages/orgs_list_message'
require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/organization_presenter'
require 'presenters/v3/organization_usage_summary_presenter'
require 'presenters/v3/to_one_relationship_presenter'

class OrganizationsV3Controller < ApplicationController
  include SubResource

  def show
    org = fetch_org(hashed_params[:guid])
    org_not_found! unless org && permission_queryer.can_read_from_org?(org.guid)

    render status: :ok, json: Presenters::V3::OrganizationPresenter.new(org)
  end

  def index
    message = OrgsListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if isolation_segment_nested?
                fetch_orgs_for_isolation_segment(message)
              else
                fetch_orgs(message)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::OrganizationPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: base_url(resource: 'organizations'),
      message: message
    )
  end

  def create
    unauthorized! unless permission_queryer.can_write_globally? || user_org_creation_enabled?

    message = VCAP::CloudController::OrganizationCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    org = OrganizationCreate.new(perm_client: perm_client, user_audit_info: user_audit_info).create(message)

    render json: Presenters::V3::OrganizationPresenter.new(org), status: :created
  rescue OrganizationCreate::Error => e
    unprocessable!(e.message)
  end

  def update
    org = fetch_editable_org(hashed_params[:guid])

    message = VCAP::CloudController::OrganizationUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    org = OrganizationUpdate.new(user_audit_info).update(org, message)

    render json: Presenters::V3::OrganizationPresenter.new(org), status: :ok
  rescue OrganizationUpdate::Error => e
    unprocessable!(e.message)
  end

  def destroy
    org = fetch_deletable_org(hashed_params[:guid])

    service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository.new(user_audit_info)
    delete_action = OrganizationDelete.new(SpaceDelete.new(user_audit_info, service_event_repository), user_audit_info)
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(Organization, org.guid, delete_action)
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: Jobs::Queues.generic).enqueue_pollable

    url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  def show_default_isolation_segment
    org = fetch_org(hashed_params[:guid])
    org_not_found! unless org && permission_queryer.can_read_from_org?(org.guid)

    isolation_segment = fetch_isolation_segment(org.default_isolation_segment_guid)

    render status: :ok, json: Presenters::V3::ToOneRelationshipPresenter.new(
      resource_path: "organizations/#{org.guid}",
      related_instance: isolation_segment,
      relationship_name: 'default_isolation_segment',
      related_resource_name: 'isolation_segments'
    )
  end

  def show_usage_summary
    org = fetch_org(hashed_params[:guid])
    org_not_found! unless org && permission_queryer.can_read_from_org?(org.guid)

    render status: :ok, json: Presenters::V3::OrganizationUsageSummaryPresenter.new(org)
  end

  def update_default_isolation_segment
    message = OrgDefaultIsoSegUpdateMessage.new(unmunged_body)
    unprocessable!(message.errors.full_messages) unless message.valid?

    org = fetch_editable_org(hashed_params[:guid])
    iso_seg_guid = message.default_isolation_segment_guid
    isolation_segment = fetch_isolation_segment(iso_seg_guid)

    SetDefaultIsolationSegment.new.set(org, isolation_segment, message)

    render status: :ok, json: Presenters::V3::ToOneRelationshipPresenter.new(
      resource_path: "organizations/#{org.guid}",
      related_instance: isolation_segment,
      relationship_name: 'default_isolation_segment',
      related_resource_name: 'isolation_segments'
    )
  rescue SetDefaultIsolationSegment::Error => e
    unprocessable!(e.message)
  end

  def index_org_domains
    org = fetch_org(hashed_params[:guid])
    org_not_found! unless org && permission_queryer.can_read_from_org?(org.guid)

    message = DomainsListMessage.from_params(query_params.except(:guid))
    domains = DomainFetcher.fetch(message, domain_readable_org_guids([org.guid]))

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::DomainPresenter,
      paginated_result: SequelPaginator.new.get_page(domains, message.try(:pagination_options)),
      path: "/v3/organizations/#{org.guid}/domains",
      message: message,
      extra_presenter_args: { visible_org_guids: permission_queryer.readable_org_guids }
    )
  end

  def show_default_domain
    org = fetch_org(hashed_params[:guid])
    org_not_found! unless org && permission_queryer.can_read_from_org?(org.guid)
    domain = org.default_domain

    domain_not_found! unless domain
    domain_not_found! if domain.private? && !permission_queryer.readable_org_guids_for_domains.include?(org.guid)

    render status: :ok, json: Presenters::V3::DomainPresenter.new(domain, visible_org_guids: permission_queryer.readable_org_guids)
  end

  private

  def domain_readable_org_guids(org_guids)
    org_guids & permission_queryer.readable_org_guids_for_domains
  end

  def fetch_editable_org(guid)
    org = fetch_org(guid)
    org_not_found! unless org && permission_queryer.can_read_from_org?(org.guid)
    unauthorized! unless roles.admin? || (org.managers.include?(current_user) && org.active?)
    org
  end

  def fetch_deletable_org(guid)
    org = fetch_org(guid)
    org_not_found! unless org && permission_queryer.can_read_from_org?(org.guid)
    unauthorized! unless roles.admin?
    org
  end

  def user_org_creation_enabled?
    VCAP::CloudController::FeatureFlag.enabled?(:user_org_creation)
  end

  def org_not_found!
    resource_not_found!(:organization)
  end

  def domain_not_found!
    resource_not_found!(:domain)
  end

  def isolation_segment_not_found!
    resource_not_found!(:isolation_segment)
  end

  def fetch_org(guid)
    Organization.where(guid: guid).first
  end

  def fetch_isolation_segment(guid)
    IsolationSegmentModel.where(guid: guid).first
  end

  def fetch_orgs(message)
    if permission_queryer.can_read_globally?
      OrgListFetcher.new.fetch_all(message: message, eager_loaded_associations: Presenters::V3::OrganizationPresenter.associated_resources)
    else
      OrgListFetcher.new.fetch(
        message: message,
        guids: permission_queryer.readable_org_guids,
        eager_loaded_associations: Presenters::V3::OrganizationPresenter.associated_resources
      )
    end
  end

  def fetch_orgs_for_isolation_segment(message)
    if permission_queryer.can_read_globally?
      isolation_segment, dataset = OrgListFetcher.new.fetch_all_for_isolation_segment(
        message: message,
        eager_loaded_associations: Presenters::V3::OrganizationPresenter.associated_resources
      )
    else
      isolation_segment, dataset = OrgListFetcher.new.fetch_for_isolation_segment(
        message: message,
        guids: permission_queryer.readable_org_guids,
        eager_loaded_associations: Presenters::V3::OrganizationPresenter.associated_resources
      )
    end
    isolation_segment_not_found! unless isolation_segment && permission_queryer.can_read_from_isolation_segment?(isolation_segment)
    dataset
  end
end

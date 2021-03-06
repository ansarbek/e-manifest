require 'date'

class Manifest < ActiveRecord::Base
  include Searchable

  validate :tracking_number, :validate_tracking_number_unique
  validates :user_id, presence: true
  belongs_to :user, class_name: 'User'

  # Elasticsearch configuration
  settings index: {
    number_of_shards: 1, # increase this if we ever get more than N records
    number_of_replicas: 1
  } do
    # with dynamic mapping==true, we only need to explicitly define overrides.
    # https://www.elastic.co/guide/en/elasticsearch/guide/current/dynamic-mapping.html
    mappings dynamic: "true" do
      indexes :content do
        indexes :generator do
          indexes :signatory do
            indexes :date, type: "string"
          end
        end
        indexes :transporters do
          indexes :signatory do
            indexes :date, type: "string"
          end
        end
        indexes :designated_facility do
          indexes :certification do
            indexes :date, type: "string"
          end
          indexes :discrepancy do
            indexes :signatory do
              indexes :date, type: "string"
            end
          end
        end
        indexes :international_shipment do
          indexes :port_of_entry_exit do
            indexes :city, type: "string"
            indexes :state, type: "string"
          end
        end
      end
    end
  end

  def self.state_fields
    [
      'generator.mailing_address.state',
      'generator.site_address.state',
      'international_shipment.port_of_entry_exit.state',
      'designated_facility.address.state',
      'designated_facility.discrepancy.address.state'
    ]
  end

  def has_state?(state)
    self.class.state_fields.select do |state_field|
      state_value = content_field(state_field)
      state_value == state
    end.any?
  end

  def content_field(json_xpath)
    fields = json_xpath.split('.')
    if content && fields.inject(content) { |h,k| h[k] if h }
      fields.inject(content) { |h,k| h[k] if h }
    end
  end

  def tracking_number
    content_field('generator.manifest_tracking_number')
  end

  def generator_name
    content_field('generator.name') || ''
  end

  def disposal_facility
    content_field('generator.disposal_facility.name')
  end

  def created_on
    created_at.strftime('%m/%d/%Y')
  end

  def generator_emergency_response_phone
    content_field('generator.emergency_response_phone')
  end

  def generator_phone_number
    content_field('generator.phone_number')
  end

  def generator_mailing_address
    content_field('generator.mailing_address') || {}
  end

  def transporters
    content_field('transporters') || []
  end

  def designated_facility
    content_field('designated_facility') || {}
  end

  def designated_facility_address
    content_field('designated_facility.address') || {}
  end

  def designated_facility_name
    content_field('designated_facility.name')
  end

  def international
  end

  def designated_facility_signed_date
    content_field('designated_facility.certification') || ''
  end

  def manifest_items
    content_field('manifest_items') || []
  end

  def waste_handling_instructions
    content_field('waste_handling_instructions')
  end

  def waste_pcb_description
    content_field('waste_pcb_description')
  end

  def waste_report_codes
    content_field('report_management_method_codes') || []
  end

  def handler_defined
    content_field('handler_defined_data') || []
  end

  def self.find_by_uuid_or_tracking_number(id)
    find_by(uuid: id) || find_by_tracking_number(id)
  end

  def self.find_by_tracking_number(tracking_number)
    find_by("content -> 'generator' ->> 'manifest_tracking_number' = ?", tracking_number.to_s)
  end

  def self.find_by_uuid_or_tracking_number!(id)
    find_by_uuid_or_tracking_number(id) or raise ManifestNotFound.new "Could not find #{id} by uuid or tracking_number"
  end

  def self.authorized_search(params, user=nil)
    dsl = Search::QueryDSL.new(params: params, user: user)
    resp = search(dsl)
    { es_response: resp, dsl: dsl }
  end

  def is_public?
    created_at < 90.days.ago
  end

  private

  def validate_tracking_number_unique
    if tracking_number.blank?
      errors.add(:tracking_number, "must be present")
    elsif tracking_number !~ /^[0-9]{9}[A-Za-z]{3}$/
      errors.add(:tracking_number, "must be 12 characters, starting with 9 numbers and ending with 3 letters")
    elsif tracking_number_already_exists?
      errors.add(:tracking_number, "must be unique")
    elsif exists_with_different_tracking_number?
      errors.add(:tracking_number, "must be unique")
    end
  end

  def tracking_number_already_exists?
    !id && Manifest.find_by_tracking_number(tracking_number)
  end

  def exists_with_different_tracking_number?
    existing = Manifest.find_by_tracking_number(tracking_number)
    id && existing && existing.id != id
  end
end

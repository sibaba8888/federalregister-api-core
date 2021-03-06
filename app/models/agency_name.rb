class AgencyName < ApplicationModel
  include CacheUtils
  belongs_to :agency
  has_many :agency_name_assignments
  has_many :entries, :through => :agency_name_assignments
  has_many :public_inspection_documents, :through => :agency_name_assignments
  has_many :agency_assignments, :dependent => :destroy

  validates_presence_of :name
  validate :does_not_have_agency_if_void

  before_create :assign_agency_if_exact_match
  after_save :update_agency_assignments
  after_save :update_agency_entries_count
  scope :unprocessed, -> { where(void: false, agency_id: nil).order("agency_names.name") }

  def self.find_or_create_by_name(name)
    cleaned_name = name.sub(/\W+$/, '')
    find_by_name(cleaned_name) || create(:name => cleaned_name)
  end

  def unprocessed?
    (!void?) && agency_id.nil?
  end

  private

  def update_agency_assignments
    if saved_change_to_agency_id?
      if agency_id_before_last_save.present?
        if agency_id.present?
          agency_assignments.each do |agency_assignment|
            agency_assignment.agency_id = agency_id
            agency_assignment.save!
          end
        else
          agency_assignments.each do |agency_assignment|
            agency_assignment.destroy
          end
        end
      else
        ActiveRecord::Base.connection.execute("INSERT INTO agency_assignments
                            (agency_id, agency_name_id, assignable_type, assignable_id, position)
                            SELECT #{agency_id} AS agency_id,
                                   agency_name_assignments.agency_name_id AS agency_name_id,
                                   agency_name_assignments.assignable_type,
                                   agency_name_assignments.assignable_id,
                                   agency_name_assignments.position
                            FROM agency_name_assignments
                            WHERE agency_name_assignments.agency_name_id = #{id}")
        Entry.where(:id => self.entry_ids).update_all(:delta => true)
        if self.entry_ids.present?
          EntryChange.insert_all(self.entry_ids.map{|entry_id| {entry_id: entry_id} })
        end
      end

      recompile_associated_tables_of_contents
      recompile_public_inspection_tables_of_contents

      SphinxIndexer.rebuild_delta_and_purge_core(Entry)
      purge_cache(".*")
    end
  end

  def recompile_public_inspection_tables_of_contents
    public_inspection_dates.each{|date| Resque.enqueue(PublicInspectionTableOfContentsRecompiler, date) }
  end

  def public_inspection_dates
    public_inspection_documents.map(&:public_inspection_issues).flatten.map(&:publication_date).uniq
  end

  def recompile_associated_tables_of_contents
    entries.
      select("DISTINCT(publication_date)").
      each{|entry| Resque.enqueue(TableOfContentsRecompiler, entry.publication_date) }
  end

  def does_not_have_agency_if_void
    errors.add(:agency_id, "must be blank if void") if (void? && agency_id.present?)
  end

  def assign_agency_if_exact_match

    agency = Agency.find_by_name(name) || Agency.find_by_name(alternative_name)
    if agency
      self.agency = agency
    end

    true
  end

  def alternative_name
    alternative_name = name.dup
    alternative_name.gsub!(/(?:U\b\.?S\b\.?|united states)/i, '') # remove U.S.

    # remove parentheticals
    alternative_name.sub!(/\(.*\)/, '')
    alternative_name.sub!(/\[.*\]/, '')
    alternative_name.sub!(/\\\\.*/, '')

    # remove semicolons on
    alternative_name.sub!(/;.*/,'')

    # remove parens on
    alternative_name.sub!(/\(.*/,'')

    # cleanup whitespace
    alternative_name.gsub!(/ {2,}/, ' ')
    alternative_name.gsub!(/^ /, '')
    alternative_name.gsub!(/ $/, '')

    alternative_name.sub!(/^(\w+) (?:of|on|for)(?: the)? (.*)/i, '\2 \1')

    alternative_name
  end

  def update_agency_entries_count
    if saved_change_to_agency_id?
      if agency_id_before_last_save.present?
        Agency.find(agency_id_before_last_save).recalculate_entries_count!
      end
      if agency
        agency.recalculate_entries_count!
      end
    end
    true
  end
end

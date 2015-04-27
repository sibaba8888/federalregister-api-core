class IndexCompiler
  attr_reader :doc_data, :agency, :year, :path_manager

  DEFAULT_SUBJECT_SQL = FrIndexPresenter::EntryPresenter::DEFAULT_SUBJECT_SQL
  SUBJECT_SQL = FrIndexPresenter::EntryPresenter::SUBJECT_SQL
  DEFAULT_DOC_SQL = FrIndexPresenter::EntryPresenter::DEFAULT_DOC_SQL
  DOC_SQL = FrIndexPresenter::EntryPresenter::DOC_SQL

  def initialize(year, agency_id)
    @agency = Agency.find(agency_id)
    @year = year.to_i
    @path_manager = FileSystemPathManager.new("#{year}-01-01")
    @doc_data = {
      name: agency.try(:name),
      slug: agency.try(:slug),
      url: agency.try(:url),
      document_categories: []
    }
  end

  def self.perform(date)
    date = date.is_a?(Date) ? date : Date.parse(date)
    year = date.strftime('%Y')
    Agency.all.each do |agency|
      if IndexCompiler.new(year, agency.id).any_documents? #TODO: Refactor to be more performant
        IndexCompiler.process_agency(year, agency.id)
      end
    end
  end

  def any_documents?
    if entries.present?
      true
    else
      false
    end
  end

  def self.process_agency(year, agency_id)
    agency_representation = new(year, agency_id)
    agency_representation.process_entries
    agency_representation.process_see_also
    agency_representation.save(agency_representation.ordered_json)
    # agency_representation.save(agency_representation.doc_data) #TODO: Backup code that works
  end

  def descendant_agency_ids(parent=agency)
    descendants = []
    parent.children.each do |child|
      descendants << child.id
      descendants << descendant_agency_ids(child) if child.children.present?
    end
    descendants.flatten
  end

  def entries
    puts agency.id
    @entries ||= Agency.find_as_hashes([
     "SELECT
        entries.document_number,
        entries.granule_class,
        #{SUBJECT_SQL} AS subject_1,
        #{DOC_SQL} AS subject_2
      FROM entries
      JOIN public_inspection_documents
        ON public_inspection_documents.document_number = entries.document_number
      JOIN agency_assignments
        ON agency_assignments.assignable_id = entries.id AND agency_assignments.assignable_type = 'Entry'
      JOIN agencies
        ON agencies.id = agency_assignments.agency_id
      WHERE
        entries.publication_date >= ? AND
        entries.publication_date <= ? AND
        agencies.id IN(?)",

      "#{year}-01-01",
      "#{year}-12-31",
      ([agency.id] + descendant_agency_ids).join(",")
    ]).
    group_by{|entry|entry["granule_class"]}
  end

  def process_entries
    puts "Number of doc types: #{entries.size}"
    puts entries.keys
    entries.each do |doc_type, doc_representations|
      @doc_data[:document_categories] << {
        name: doc_type,
        documents: process_documents(doc_representations)
      }
    end
  end

  def process_documents(doc_representations)
    hsh = {}
    doc_representations.each do |doc_representation|
      formatted_doc = format_subjects(doc_representation)

      if hsh[subject_1: formatted_doc[:subject_1], subject_2: formatted_doc[:subject_2]]
        hsh[subject_1: formatted_doc[:subject_1], subject_2: formatted_doc[:subject_2]][:document_numbers] << doc_representation["document_number"]
      else
        hsh[subject_1: formatted_doc[:subject_1], subject_2: formatted_doc[:subject_2]] = formatted_doc
      end

    end
    hsh.values.sort_by{|k,v|[k[:subject_1],k[:subject_2]]}.each {|k,v|k[:document_numbers].sort!}
  end

  def format_subjects(doc_representation)
    if doc_representation["subject_1"].blank?
      {
        subject_1: doc_representation["subject_2"],
        subject_2: "",
        document_numbers: [doc_representation["document_number"] ]
      }
    else
      {
        subject_1: doc_representation["subject_1"],
        subject_2: doc_representation["subject_2"],
        document_numbers: [doc_representation["document_number"] ]
      }
    end
  end

  def process_see_also
    doc_data[:see_also] = agency.children.map do |child_agency|
      {
        name: child_agency.name,
        slug: child_agency.slug
      }
    end if agency.children.present?
    #TODO: Should all child agencies be displayed or only agencies with associated entries?
  end

  def ordered_json
    ordered_doc_data = {
      name: agency.try(:name),
      slug: agency.try(:slug),
      url: agency.try(:url),
      document_categories: []
    }

    rules = doc_data[:document_categories].find{|cat|cat[:name]=="RULE"}
    prorules = doc_data[:document_categories].find{|cat|cat[:name]=="PRORULE"}
    notices = doc_data[:document_categories].find{|cat|cat[:name]=="NOTICE"}
    presdocs = doc_data[:document_categories].find{|cat|cat[:name]=="PRESDOCU"}
    unknown_docs = doc_data[:document_categories].find{|cat|cat[:name]=="UNKNOWN"}

    ordered_doc_data[:document_categories] << rules unless rules.nil?
    ordered_doc_data[:document_categories] << prorules unless prorules.nil?
    ordered_doc_data[:document_categories] << notices unless notices.nil?
    ordered_doc_data[:document_categories] << presdocs unless presdocs.nil?
    ordered_doc_data[:document_categories] << unknown_docs unless unknown_docs.nil?
    # puts "There are #{ordered_doc_data[:document_categories].size} categories in ordered doc data: #{ordered_doc_data[:document_categories].map{|x|x[:name]}}"
    ordered_doc_data
  end

  def save(document_data)
    FileUtils.mkdir_p(path_manager.index_json_dir)

    File.open json_index_path, 'w' do |f|
      f.write(document_data.to_json)
    end
  end


  private

  def json_index_path
    # "data/fr_index/2015/sample_agency.json"
    "#{path_manager.index_json_dir}#{agency.slug}.json" #TODO: Remove static stub
  end

end

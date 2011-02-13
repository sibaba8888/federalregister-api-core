class Subscription < ApplicationModel
  before_create :generate_token
  after_create :ask_for_confirmation
  before_save :update_mailing_list_active_subscriptions_count
  
  belongs_to :mailing_list
  
  def to_param
    token
  end
  
  def mailing_list_with_autobuilding
    if mailing_list_without_autobuilding.nil? && search_conditions.present?
      search = EntrySearch.new(:conditions => search_conditions)
      self.mailing_list = MailingList.find_by_search(search) || MailingList.new(:search => search)
    else
      mailing_list_without_autobuilding
    end
  end
  
  alias_method_chain :mailing_list, :autobuilding
  
  validates_presence_of :email, :requesting_ip, :mailing_list
  
  def active?
    confirmed_at.present? && unsubscribed_at.nil?
  end
  
  def was_active?
    confirmed_at_was.present? && unsubscribed_at_was.nil?
  end
  
  attr_accessor :search_conditions
  
  private
  
  def ask_for_confirmation
    Mailer.deliver_subscription_confirmation(self)
  end
  
  def generate_token
    self.token = SecureRandom.hex(20)
  end
  
  def update_mailing_list_active_subscriptions_count
    if was_active? && ! active?
      MailingList.decrement_counter(:active_subscriptions_count, mailing_list_id)
    elsif !was_active? && active?
      MailingList.increment_counter(:active_subscriptions_count, mailing_list_id)
    end
    
    true
  end
end
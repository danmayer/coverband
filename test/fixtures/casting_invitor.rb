class CastingInviter
  EMAIL_REGEX = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/

  attr_reader :message, :invitees, :casting

  def initialize(attributes = {})
    @message = attributes[:message] || ""
    @invitees = attributes[:invitees] || ""
    @sender = attributes[:sender]
    @casting = attributes[:casting]
  end

  def valid?
    valid_message? && valid_invitees?
  end

  def deliver
    if valid?
      invitee_list.each do |email|
        invitation = create_invitation(email)
        Mailer.invitation_notification(invitation, @message)
      end
    else
      failure_message =
        "Your #{
          @casting
        } message couldn’t be sent. Invitees emails or message are invalid"
      invitation = create_invitation(@sender)
      Mailer.invitation_notification(invitation, failure_message)
    end
  end

  private

  def invalid_invitees
    @invalid_invitees ||=
      invitee_list.map { |item| item unless item.match(EMAIL_REGEX) }.compact
  end

  def invitee_list
    @invitee_list ||= @invitees.gsub(/\s+/, "").split(/[\n,;]+/)
  end

  def valid_message?
    @message.present?
  end

  def valid_invitees?
    invalid_invitees.empty?
  end

  def create_invitation(email)
    Invitation.create(
      casting: @casting,
      sender: @sender,
      invitee_email: email,
      status: "pending"
    )
  end
end

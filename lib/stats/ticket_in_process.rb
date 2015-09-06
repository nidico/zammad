# Copyright (C) 2012-2013 Zammad Foundation, http://zammad-foundation.org/

class Stats::TicketInProcess

  def self.generate(user)

    open_state_ids = Ticket::State.by_category('open').map(&:id)

    # get history entries of tickets worked on today
    history_object = History::Object.lookup(name: 'Ticket')

    own_ticket_ids = Ticket.select('id').where(owner_id: user.id, state_id: open_state_ids).map(&:id)

    count = History.select('DISTINCT(o_id)').where(
      'histories.created_at >= ? AND histories.history_object_id = ? AND histories.created_by_id = ? AND histories.o_id IN (?)', Time.zone.now - 1.day, history_object.id, user.id, own_ticket_ids
    ).count

    total = own_ticket_ids.count
    in_process_precent = 0
    state = 'supergood'
    average_in_percent = '-'

    if count != 0 && total != 0
      in_process_precent = (count * 1000) / ((total * 1000) / 100)
      if in_process_precent > 80
        state = 'supergood'
      elsif in_process_precent > 60
        state = 'good'
      elsif in_process_precent > 40
        state = 'ok'
      elsif in_process_precent > 20
        state = 'bad'
      elsif in_process_precent > 5
        state = 'superbad'
      end
    end

    {
      state: state,
      in_process: count,
      percent: in_process_precent,
      average_percent: average_in_percent,
      total: total,
    }
  end

end
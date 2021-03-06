# Copyright (C) 2012-2016 Zammad Foundation, http://zammad-foundation.org/
module Ticket::ScreenOptions

=begin

list attributes

  result = Ticket::ScreenOptions.attributes_to_change(
    ticket_id: 123,
    article_id: 123,

    ticket: ticket_model,
  )

returns

  result = {
    type_id:            type_ids,
    state_id:           state_ids,
    priority_id:        priority_ids,
    owner_id:           owner_ids,
    group_id:           group_ids,
    group_id__owner_id: groups_users,
  }

=end

  def self.attributes_to_change(params)
    if params[:ticket_id]
      params[:ticket] = Ticket.find(params[:ticket_id])
    end
    if params[:article_id]
      params[:article] = Ticket::Article.find(params[:article_id])
    end

    filter = {}
    assets = {}

    # get ticket states
    state_ids = []
    if params[:ticket]
      state_type = params[:ticket].state.state_type
    end
    state_types = ['open', 'closed', 'pending action', 'pending reminder']
    if state_type && !state_types.include?(state_type.name)
      state_ids.push params[:ticket].state.id
    end
    state_types.each { |type|
      state_type = Ticket::StateType.find_by(name: type)
      next if !state_type
      state_type.states.each { |state|
        assets = state.assets(assets)
        state_ids.push state.id
      }
    }
    filter[:state_id] = state_ids

    # get priorities
    priority_ids = []
    Ticket::Priority.where(active: true).each { |priority|
      assets = priority.assets(assets)
      priority_ids.push priority.id
    }
    filter[:priority_id] = priority_ids

    type_ids = []
    if params[:ticket]
      types = %w(note phone)
      if params[:ticket].group.email_address_id
        types.push 'email'
      end
      types.each { |type_name|
        type = Ticket::Article::Type.lookup( name: type_name )
        if type
          type_ids.push type.id
        end
      }
    end
    filter[:type_id] = type_ids

    # get group / user relations
    agents = {}
    User.with_permissions('ticket.agent').each { |user|
      agents[ user.id ] = 1
    }

    dependencies = { group_id: { '' => { owner_id: [] } } }
    Group.where(active: true).each { |group|
      assets = group.assets(assets)
      dependencies[:group_id][group.id] = { owner_id: [] }
      group.users.each { |user|
        next if !agents[ user.id ]
        assets = user.assets(assets)
        dependencies[:group_id][ group.id ][ :owner_id ].push user.id
      }
    }

    {
      assets: assets,
      form_meta: {
        filter: filter,
        dependencies: dependencies,
      }
    }
  end

=begin

list tickets by customer groupd in state categroie open and closed

  result = Ticket::ScreenOptions.list_by_customer(
    customer_id: 123,
    limit:       15, # optional, default 15
  )

returns

  result = {
    ticket_ids_open:   tickets_open,
    ticket_ids_closed: tickets_closed,
    assets:            { ...list of assets... },
  }

=end

  def self.list_by_customer(data)

    # get closed/open states
    state_list_open   = Ticket::State.by_category( 'open' )
    state_list_closed = Ticket::State.by_category( 'closed' )

    # get tickets
    tickets_open = Ticket.where(
      customer_id: data[:customer_id],
      state_id: state_list_open
    ).limit( data[:limit] || 15 ).order('created_at DESC')
    assets = {}
    ticket_ids_open = []
    tickets_open.each { |ticket|
      ticket_ids_open.push ticket.id
      assets = ticket.assets(assets)
    }

    tickets_closed = Ticket.where(
      customer_id: data[:customer_id],
      state_id: state_list_closed
    ).limit( data[:limit] || 15 ).order('created_at DESC')
    ticket_ids_closed = []
    tickets_closed.each { |ticket|
      ticket_ids_closed.push ticket.id
      assets = ticket.assets(assets)
    }

    {
      ticket_ids_open: ticket_ids_open,
      ticket_ids_closed: ticket_ids_closed,
      assets: assets,
    }
  end
end

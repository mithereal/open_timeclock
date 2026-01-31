defmodule Timeclock.Menu do
  @menu [
    %{
      name: "Order",
      description: "",
      icon: "",
      src: "/images/order.png",
      srcset: "",
      sizes: "",
      width: "100px",
      height: "100px",
      sort_order: 1,
      category: "sales",
      icon: "hero-banknotes",
      link: "/home/orders",
      show_on_dashboard: true,
      show_on_sidebar: true
    },
    %{
      name: "Quote",
      description: "",
      icon: "",
      src: "/images/quote.png",
      srcset: "",
      sizes: "",
      width: "100px",
      height: "100px",
      sort_order: 2,
      category: "sales",
      icon: "hero-chat-bubble-left",
      link: "/home/quotes",
      show_on_dashboard: true,
      show_on_sidebar: true
    },
    %{
      name: "Invoice",
      description: "",
      icon: "",
      src: "/images/invoice.png",
      srcset: "",
      sizes: "",
      width: "100px",
      height: "100px",
      sort_order: 3,
      category: "sales",
      icon: "hero-banknotes",
      link: "/home/invoices",
      show_on_dashboard: true,
      show_on_sidebar: true
    },
    %{
      name: "Customers",
      description: "",
      icon: "",
      src: "/images/customer.png",
      srcset: "",
      sizes: "",
      width: "100px",
      height: "100px",
      sort_order: 3,
      category: "sales",
      icon: "hero-user-group",
      link: "/home/customers",
      show_on_dashboard: true,
      show_on_sidebar: true
    },
    %{
      name: "Production",
      description: "production",
      icon: "",
      src: "/images/production.png",
      srcset: "",
      sizes: "",
      width: "100px",
      height: "100px",
      sort_order: 1,
      category: "production",
      icon: "hero-banknotes",
      link: "/home/production",
      show_on_dashboard: true,
      show_on_sidebar: true
    },
    %{
      name: "Jobs",
      description: "",
      src: "/images/jobs.png",
      icon: "",
      srcset: "",
      sizes: "",
      width: "100px",
      height: "100px",
      sort_order: 2,
      category: "production",
      icon: "hero-banknotes",
      link: "/home/jobs",
      show_on_dashboard: true,
      show_on_sidebar: true
    },
    %{
      name: "Shipment",
      description: "",
      icon: "",
      src: "/images/shipment.png",
      srcset: "",
      sizes: "",
      width: "100px",
      height: "100px",
      sort_order: 3,
      category: "production",
      icon: "hero-banknotes",
      link: "/home/shipments",
      show_on_dashboard: true,
      show_on_sidebar: true
    },
    %{
      name: "Tasks",
      description: "Setup Tasks",
      src: "/images/tasks.png",
      icon: "",
      srcset: "",
      sizes: "",
      width: "100px",
      height: "100px",
      sort_order: 4,
      category: "production",
      icon: "hero-banknotes",
      link: "/home/tasks",
      show_on_dashboard: true,
      show_on_sidebar: true
    },
    %{
      name: "Approvals",
      description: "",
      icon: "",
      src: "/images/approvals.png",
      srcset: "",
      sizes: "",
      width: "100px",
      height: "100px",
      sort_order: 5,
      category: "production",
      icon: "hero-banknotes",
      link: "/home/approvals",
      show_on_dashboard: true,
      show_on_sidebar: true
    },
    %{
      name: "Packages",
      description: "",
      src: "/images/packages.png",
      srcset: "",
      sizes: "",
      width: "100px",
      height: "100px",
      sort_order: 6,
      category: "production",
      icon: "hero-banknotes",
      link: "/home/packages",
      show_on_dashboard: true,
      show_on_sidebar: true
    },
    %{
      name: "Sales",
      description: "",
      src: "/images/sales.png",
      srcset: "",
      sizes: "",
      width: "100px",
      height: "100px",
      sort_order: 6,
      category: "sales",
      icon: "hero-banknotes",
      link: "/sales",
      show_on_dashboard: true,
      show_on_sidebar: true
    }
  ]

  alias Timeclock.Utils

  def sidebar() do
    menu = @menu
    {:ok, menu}
  end

  def dashboard() do
    menu = Utils.CategoryMapper.group_by_category(@menu)
    {:ok, menu}
  end
end

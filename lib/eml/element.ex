defmodule Eml.Element do
  @moduledoc """
  `Eml.Element` defines a struct that represents an element in Eml.

  In practice, you will mostly use the element macro's instead of directly
  creating `Eml.Element` structs, but the functions in this module can be
  valuable when querying, manipulating or transforming `eml`.
  """
  alias __MODULE__, as: El

  defstruct tag: :div, content: [], attrs: %{}

  @type content       :: [Eml.t]
  @type attr_name     :: atom
  @type attr_value    :: String.t | Eml.Parameter.t | [String.t | Eml.Parameter]
  @type attrs         :: %{ attr_name => attr_value }
  @type attr_value_in :: String.t | atom | number | Eml.Parameter.t | [String.t | atom | number | Eml.Parameter.t]
  @type attrs_in      :: [{ attr_name, attr_value_in }]
                       | %{ attr_name => attr_value_in }

  @type t :: %El{tag: atom, content: content, attrs: attrs}

  @doc "Creates a new `Eml.Element` structure with default values."
  @spec new() :: t
  def new(), do: %El{}

  @doc """
  Creates a new `Eml.Element` structure.

  ### Example
      iex> e = Eml.Element.new(:div, [id: 42], "hallo!")
      #div<%{id: "42"} ["hallo!"]>
      iex> Eml.render(e)
      "<div id='42'>hallo!</div>"

  """
  @spec new(atom, attrs_in, Eml.Data.t) :: t
  def new(tag, attrs \\ %{}, content \\ []) when is_atom(tag) and (is_map(attrs) or is_list(attrs)) do
    attrs   = to_attrs(attrs)
    content = Eml.to_content(content)
    %El{tag: tag, attrs: attrs, content: content}
  end

  @doc "Gets the tag of an element."
  @spec tag(t) :: atom
  def tag(%El{tag: tag}), do: tag

  @doc "Sets the tag of an element."
  @spec tag(t, atom) :: t
  def tag(%El{} = el, tag)
  when is_atom(tag), do: %{el| "__tag__": tag}

  @doc """
  Gets the id of an element.
  Returns `nil` if the `id` attribute is not set for the element.
  """
  @spec id(t) :: attr_value
  def id(%El{attrs: attrs}), do: attrs[:id]

  @doc "Sets the id of an element."
  @spec id(t, attr_value_in) :: t
  def id(%El{attrs: attrs} = el, id),
  do: %El{el| attrs: Map.put(attrs, :id, to_attr_value(id))}

  @doc """
  Gets the class or classes of an element.

  Multiple classes are stored in the form `["class1", "class2"]`.
  """
  @spec class(t) :: attr_value
  def class(%El{attrs: attrs}), do: attrs[:class]


  @doc """
  Sets the class or classes of an element.

  Multiple classes can be assigned by providing a list of strings.
  """
  @spec class(t, attr_value_in) :: t
  def class(%El{attrs: attrs} = el, class),
  do: %El{el| attrs: Map.put(attrs, :class, to_attr_value(class))}

  @doc """
  Gets the content of an element.

  Note that content in Eml always is a list, so when an element's
  content is empty, it returns an empty list.
  """
  @spec content(t) :: content
  def content(%El{content: content}), do: content

  @doc """
  Sets the content of an element.

  Before being assigned to the element, input
  data is parsed to valid `eml`.

  ### Example

      iex> div = Eml.Element.new(:div, [], [])
      #div<>
      iex> Eml.Element.content(div, ["Hallo ", 2, 0, [1, 5]])
      #div<["Hallo 2015"]>

  """
  @spec content(t, Eml.Data.t) :: t
  def content(%El{} = el, data) do
    %El{el| content: Eml.to_content(data)}
  end

  @doc """
  Adds content to an element.

  Before being added to the element, input
  data is parsed to valid `eml`.

  ### Example

      iex> div = Eml.Element.new(:div, [], [])
      #div<>
      iex> div = Eml.Element.content(div, ["Hallo ", 2, 0, [1, 5]])
      #div<["Hallo 2015"]>
      iex> Eml.Element.add(div, " !!!")
      #div<["Hallo 2015 !!!"]>

  """
  @spec add(t, Eml.Data.t, Keyword.t) :: t
  def add(%El{content: current} = el, data, opts \\ []) do
    at      = opts[:at] || :end
    content = Eml.to_content(data, current, at)
    %El{el| content: content}
  end

  @doc """
  Update content in an element by calling fun on the content to get new content.

  Before being added to the element, input
  data is parsed to valid `eml`.

  ### Example

      iex> div = Eml.Element.new(:div, [], "hallo")
      #div<["hallo"]>
      iex> Eml.Element.update(div, fn content -> String.upcase(content) end)
      #div<["HALLO"]>

  """
  @spec update(t, (Eml.t -> Eml.Data.t)) :: t
  def update(%El{content: content} = el, fun) do
    content = for node <- content, data = fun.(node) do
      Eml.Data.to_eml(data)
    end
    %El{el| content: content}
  end

  @doc """
  Removes content from an element that matches any term in the `to_remove`
  list.

  ### Example

      iex> div1 = Eml.Element.new(:div, [], "hallo")
      #div<["hallo"]>
      iex> div2 = Eml.Element.new(:div, [], "world")
      #div<["world"]>
      iex> div3 = Eml.Element.new(:div, [], [div1, div2])
      #div<[#div<["hallo"]>, #div<["world"]>]>
      iex> Eml.Element.remove(div3, [div1, div2])
      #div<>

  """
  @spec remove(t, Eml.t | content) :: t
  def remove(%El{content: content} = el, to_remove) do
    to_remove = if is_list(to_remove), do: to_remove, else: [to_remove]
    content = for node <- content, not node in to_remove do
      node
    end
    %El{el| content: content}
  end

  @doc "Gets the attributes map of an element."
  @spec attrs(t) :: attrs
  def attrs(%El{attrs: attrs}), do: attrs

  @doc "Merges the passed attributes with the current attributes."
  @spec attrs(t, attrs_in) :: t
  def attrs(%El{attrs: current} = el, attrs) when is_map(attrs) or is_list(attrs) do
    %El{el| attrs: Map.merge(current, to_attrs(attrs))}
  end

  @doc """
  Gets a specific attribute.

  If the attribute does not exist, nil is returned.
  """
  @spec attr(t, atom) :: attr_value
  def attr(%El{attrs: attrs}, field) when is_atom(field) do
    attrs[field]
  end

  @doc """
  Sets a attribute.

  If the attribute already exists, the old value gets overwritten.
  """
  @spec attr(t, atom, attr_value_in) :: t
  def attr(%El{attrs: attrs} = el, field, value) when is_atom(field) do
    %El{el| attrs: Map.put(attrs, field, to_attr_value(value))}
  end

  @doc false
  @spec insert_attr_value(t, atom, attr_value_in) :: t
  def insert_attr_value(%El{attrs: attrs} = el, field, value) when is_atom(field) do
    %El{el| attrs: Map.update(attrs, field, to_attr_value(value), &insert_attr_value(&1, value))}
  end

  defp insert_attr_value(old, new) do
    old = ensure_list(old)
    new = ensure_list(new)
    for v <- new do
      to_attr_value(v)
    end ++ old
  end

  @doc "Removes an attribute from an element."
  @spec remove_attr(t, atom) :: t
  def remove_attr(%El{attrs: attrs} = el, field) do
    %El{el| attrs: Map.delete(attrs, field)}
  end

  @doc """
  Returns true if all properties of the opts argument are matching with the provided element.

  ### Example

      iex> e = Eml.Element.new(:img, id: "duck-photo", src: "http://i.imgur.com/4xPWp.jpg")
      #img<%{id: "duck-photo", src: "http://i.imgur.com/4xPWp.jpg"}>
      iex> Eml.Element.has?(e, id: "duck-photo")
      true
      iex> Eml.Element.has?(e, src: "http://i.imgur.com/4xPWp.jpg")
      true
      iex> Eml.Element.has?(e, src: "http://i.imgur.com/4xPWp.jpg", id: "wrong")
      false
  """
  @spec has?(t, Keyword.t) :: boolean
  def has?(%El{} = el, opts) when is_list(opts) do
    { tag, opts }      = Keyword.pop(opts, :tag, :any)
    { id, opts }       = Keyword.pop(opts, :id, :any)
    { class, opts }    = Keyword.pop(opts, :class, :any)
    { content, attrs } = Keyword.pop(opts, :content)
    content            = Eml.to_content(content)
    content            = if content == [], do: :any, else: content

    has_tag?(el, tag)         and
    has_id?(el, id)           and
    has_class?(el, class)     and
    has_content?(el, content) and
    has_attrs?(el, attrs)
  end
  def has?(_non_el, _opts), do: false

  defp has_tag?(_, :any), do: true
  defp has_tag?(%El{tag: etag}, tag), do: tag === etag

  defp has_id?(_, :any), do: true
  defp has_id?(%El{attrs: %{id: eid}}, id), do: id === eid
  defp has_id?(_, _), do: false

  defp has_class?(_, :any), do: true
  defp has_class?(%El{attrs: %{class: eclass}}, classes) when is_list(classes) do
    Enum.all?(classes, &class?(&1, eclass))
  end
  defp has_class?(%El{attrs: %{class: eclass}}, class), do: class?(class, eclass)
  defp has_class?(_, _), do: false

  defp has_content?(_, :any), do: true
  defp has_content?(%El{content: econtent}, content) do
    Enum.all?(content, &Kernel.in(&1, econtent))
  end

  defp has_attrs?(_, []), do: true
  defp has_attrs?(el, attrs) do
    eattrs = attrs(el)
    Enum.all?(attrs, fn attr ->
      attr?(attr, eattrs)
    end)
  end

  defp attr?({ field, value }, attrs) do
    Enum.any?(attrs, fn { f, v } ->
      field === f and (value === :any or value === v)
    end)
  end

  @doc false
  def match?(_, tag, id \\ :any, class \\ :any)

  def match?(_, :any, :any, :any),
  do: true

  def match?(%El{tag: etag}, tag, :any, :any),
  do: tag === etag

  def match?(%El{attrs: %{id: eid}}, :any, id, :any),
  do: id === eid

  def match?(%El{attrs: %{class: eclass}}, :any, :any, class),
  do: class?(class, eclass)

  def match?(%El{tag: etag, attrs: %{id: eid}}, tag, id, :any),
  do: tag === etag and id === eid

  def match?(%El{tag: etag, attrs: %{class: eclass}}, tag, :any, class),
  do: tag === etag and class?(class, eclass)

  def match?(%El{ attrs: %{id: eid, class: eclass}}, :any, id, class),
  do: id === eid and class?(class, eclass)

  def match?(%El{tag: etag, attrs: %{id: eid, class: eclass}}, tag, id, class),
  do: tag === etag and id === eid and class?(class, eclass)

  def match?(_, _, _, _),
  do: false

  defp class?(class, classes) do
    if is_list(classes),
      do:   class in classes,
      else: class === classes
  end

  @doc false
  def maybe_include(attrs1, attrs2) do
    for { field, value } <- attrs2, value != nil, into: attrs1 do
      { field, value }
    end
  end

  defp to_attrs(nil), do: %{}
  defp to_attrs(collection) do
    for { field, value } <- collection, value != nil, into: %{} do
      { field, to_attr_value(value) }
    end
  end

  defp to_attr_value(nil),    do: nil
  defp to_attr_value([]),     do: nil
  defp to_attr_value([data]), do: to_attr_value(data)

  defp to_attr_value(list) when is_list(list) do
    res = for data <- list, data != nil do
      to_attr_value(data)
    end |> :lists.flatten()
    if res === [], do: nil, else: res
  end

  defp to_attr_value(%Eml.Parameter{} = param), do: param
  defp to_attr_value(param) when is_atom(param)
  and not param in [true, false], do: %Eml.Parameter{id: param, type: :attr}

  defp to_attr_value(data), do: to_string(data)

  @doc false
  def ensure_list(data) when is_list(data), do: data
  def ensure_list(""),                      do: []
  def ensure_list(data),                    do: [data]

end

# Enumerable protocol implementation

defimpl Enumerable, for: Eml.Element do

  def count(_el),           do: { :error, __MODULE__ }
  def member?(_el, _),      do: { :error, __MODULE__ }

  def reduce(el, acc, fun) do
    case reduce_content([el], acc, fun) do
      { :cont, acc }    -> { :done, acc }
      { :suspend, acc } -> { :suspended, acc }
      { :halt, acc }    -> { :halted, acc }
    end
  end

  defp reduce_content(_, { :halt, acc }, _fun) do
    { :halt, acc }
  end
  defp reduce_content(content, { :suspend, acc }, fun) do
    { :suspend, acc, &reduce_content(content, &1, fun) }
  end
  defp reduce_content([%Eml.Element{content: content} = el | rest], { :cont, acc }, fun) do
    reduce_content(rest, reduce_content(content, fun.(el, acc), fun), fun)
  end
  defp reduce_content([node | rest], { :cont, acc }, fun) do
    reduce_content(rest, fun.(node, acc), fun)
  end
  defp reduce_content([], acc, _fun) do
    acc
  end
end

# Inspect protocol implementation

defimpl Inspect, for: Eml.Element do
  import Inspect.Algebra

  def inspect(%Eml.Element{tag: tag, attrs: attrs, content: content}, opts) do
    opts = if is_list(opts), do: Keyword.put(opts, :hide_content_type, true), else: opts
    tag   = Atom.to_string(tag)
    attrs = if attrs == %{}, do: "", else: to_doc(attrs, opts)
    content  = if Eml.empty?(content), do: "", else: to_doc(content, opts)
    fields = case { attrs, content } do
               { "", "" } -> ""
               { "", _ }  -> content
               { _, "" }  -> attrs
               { _, _ }   -> glue(attrs, " ", content)
             end
    concat ["#", tag, "<", fields, ">"]
  end
end

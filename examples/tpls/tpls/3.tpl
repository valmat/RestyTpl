Привет!
Как дела? Template № 1 ..
||{{message}}||
________________


{% for key, value in pairs(keywords) do %}
    {{key}} {{value}}
{% end %}

{% for key, value in pairs(keywords) do %}
    {{key}} {{value}}
{% end %}

values:
{% for key, value in pairs(values) do %}
    {{key}} {{value}}
{% end %}


range1

{% for value in iota1(1, 10)  do %}
   {{value}}
{% end %}

{% for value in range1()  do %}
   {{value}}
{% end %}


{% for value in iota2(1, 10, 1)()  do %}
   {{value}}
{% end %}

\{\{qqq\}\}

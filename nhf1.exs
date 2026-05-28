defmodule Nhf1 do
  @moduledoc """
  Számtekercs
  @author "Egyetemi Hallgató <egy.hallg@edu.bme.hu>"
  @date   "2025-10-24"
  ...
  """
      @type size()  :: integer() # tábla mérete (0 < n)
      @type cycle() :: integer() # ciklus hossza (0 < m <= n)
      @type value() :: integer() # mező értéke (0 < v <= m)

      @type row()   :: integer()       # sor száma (1-től n-ig)
      @type col()   :: integer()       # oszlop száma (1-től n-ig)
      @type field() :: {row(), col()}  # mező koordinátái

      @type field_value() :: {field(), value()}                 # mező és értéke
      @type puzzle_desc() :: {size(), cycle(), [field_value()]} # feladvány

      @type retval()    :: integer()    # eredménymező értéke (0 <= rv <= m)
      @type solution()  :: [[retval()]] # egy megoldás
      @type solutions() :: [solution()] # összes megoldás

      @spec helix(sd::puzzle_desc()) :: ss::solutions()
      # ss az sd feladványleíróval megadott feladvány összes megoldásának listája
      def helix({size,cycle,fields}) do
        #felépítem a field_list listát, amely egy lista a {rown, column} értékekkel,
        #  mely tekeredő bejárás szerinti sorban megadja a sor és oszlop értékekek
        #és ennek az úgymond inverzét, azaz egy koordináta -> index map-et
        {field_list,field_to_index_map} = field_list_and_map_builder(size,1,[])
        #felépítek egy m hosszú prímszámokat tartalmazó tömböt
        primes = prime_array_builder(cycle)
        
        #felépítem a conditions tömböt
        conditions = conditions_array_builder(size,fields,primes)

        
        #a nullás megkötések kivételével szekciókra bontom a tekeredő bejárást a megkötések mentén,
        #majd a szekciók lehetséges nulla elosztását megkapom 
        #elősször kigyűjtöm a nullás megkötések indexeit:

        #a megkötéseket átalakítom koordináták helyett index alapuakká
        const_with_index_sorted =
          fields
          |> Enum.map(fn {{row, col}, value} ->
            {Map.get(field_to_index_map, {row, col}), value}
          end)
          |> Enum.sort_by(fn {indx, _val} -> indx end)
        
        #elősször a nullás megkötéseknek eltárolom (és rendezem biztos ami biztos) a pozíciójukat
        
        zeros_const_positions = Enum.sort(
          for {a, b} <- const_with_index_sorted, b === 0, do: a-1
        )
      
        #a megkötésekből összegyűjtöm a nem nullás megkötéseiket, 
        #       és csökkentem az indexeiket annyival amennyi nullás mgekötés lett volna előtte
        constraints_without_zeros = 
        const_with_index_sorted
        #sorbarendezett megkötéseken végig megyek egy kételemű aksival, 
        #egyikbe gyűjtöm a nem nullás megkötéseket, másikba tárolom az aktuális eltolás mértékét
        |> Enum.reduce({[],0}, fn {index,val},{acc,shift} ->
          if val === 0 do
            {acc, shift+1}
          else
            {[{index-shift,val}|acc],shift}
          end
            
          end)
        |> elem(0)
        |>Enum.reverse()
        
    
        #kiszámolom minden szekcióra a minimum nullások számát és a maximumét (vagyis pontosabban azt a maximális x értéket, amire a szekcióba beleférhet min+x*m nullás)
        minmaxes = min_max_distribution(0,cycle,cycle,size*size-length(zeros_const_positions),constraints_without_zeros)
        #végig megyek hogy hényfélekéépen szórhatom szét a nullásokat a szekciók között
        poss_distributions = 
        possible_zeros_distribution_recursive(
              Enum.map(minmaxes,fn {_a,b} -> b end),
              div(size*size-size*cycle-Enum.reduce(minmaxes,0,fn {a,_}, acc -> acc + a end),cycle),cycle,
              Enum.map(minmaxes,fn {a,_b} -> a end))
        #IO.inspect(poss_distributions)
        #megoldhatatlan esetben üres listát adok vissza
        if poss_distributions == [-1] do
          []
        else
              # a lehetséges 0 eloszlások listák listáját tovább adom az összegyűjtú metódusnak de kilapítva gyűjtöm ezeket össze
          Enum.flat_map(poss_distributions,
            fn one_zero_dist -> 
              #egy konkrét nulla elosztásra vizsgálom a lehetséges megoldásokat

              helix_rec_builder(cycle,1,field_list,conditions,primes,one_zero_dist,0,cycle,size,const_with_index_sorted++[{size*size+1,1}],field_to_index_map,[])

            end
            )
          
        end
      end






@spec possible_zeros_distribution_recursive(list::[integer()],z::integer(),m::cycle(),tied::[integer()])::[[integer()]]
  # segétmetódus ami megkapja a list listában hogy melyik szekcióban maximum hányszor m-nyi nullás fér el
  #  és a számmal hogy összesen hányszor m nullásnak van szabad mozgási helye (értsd. nincs fixen egy szekcióba kényszerítve)
  # visszatért a különböző jó 0 elosztásokkal
  def possible_zeros_distribution_recursive([akt|[_sm|_sms]=rest],z,m,[akt_tied|rest_tied]) do 
    if Enum.sum([akt|rest])<z or Enum.any?([akt_tied|rest_tied]++[akt|rest], fn x -> x < 0 end) do
      #az az eset, amikor nem lehet elosztani a nullásokat
      #  vagy mert nincs elég
      #  vagy mert egy szekcióba negatív számu minimum nullás kell (vagyis nincs elég cella hogy a szekció előtti utolsó elemből novekvő sorrendbe elérjen a szekció utáni első elemhez)
      [-1]
    else
      ##nem kéne, de a warningok miatt lecsekkolom
      starting_x = max(0, z - Enum.sum(rest))
      ending_x = min(akt, z)
      if ending_x>=starting_x do
        #Stream.flat_map(starting_x..ending_x, fn x ->
        #  possible_zeros_distribution_recursive(rest, z - x, m, rest_tied)
        #  |> Stream.map(fn rest_made -> [x*m + akt_tied | rest_made] end)
        #end)
        for x <- starting_x..ending_x,
          rest_made <- possible_zeros_distribution_recursive(rest,z-x,m,rest_tied) do
          [x*m+akt_tied|rest_made]
        end
      else
        []
      end
      
      #for x <- max(0,z-Enum.sum(rest))..min(akt,z),
      #  rest_made <- possible_zeros_distribution_recursive(rest,z-x,m,rest_tied) do
      #  [x*m+akt_tied|rest_made]
      #end
    end
  end  
  def possible_zeros_distribution_recursive([_akt|[]],z,m,[akt_tied|_r]), do: [[z*m+akt_tied]]

  
@spec min_max_distribution(ij::integer(),j::value(),m::cycle(),len::size(),constraints::[{integer(),value()}])::{min::integer(),max::integer()}
  #minden szekcióra visszaad a a minimális zero és maxi szám párost {min,max}
  # min = legkevesebb kötelező nullás a szekcióban
  # max = max(x) : min+m*x db nullás elhelyezhető a szekcióban
  def min_max_distribution(ij,j,m,len,[{ik,k}|constraints]) do
    sect_len = ik-ij-1
    [
      
      if j>= k do
        {
          sect_len  -  ( (m-j) + (k-1) + m*div(sect_len-(m-j)-(k-1),m) )   ,
          div(sect_len-(m-j)-(k-1),m)
        } 
      else
        {
          sect_len  -  ( (k-j-1) + m*div(sect_len-(k-j-1),m) )   ,
          div(sect_len-(k-j-1),m)         
        }      
      end
        ] ++ min_max_distribution(ik,k,m,len,constraints)
  end
  
  def min_max_distribution(ij,j,m,len,[]) do
    sect_len = len+1-ij-1
    [
      
        {
          sect_len  -  ( (m-j) + m*div(sect_len-(m-j),m) )   ,
          div(sect_len-(m-j),m)
        }
    ]
  end
  
  


  
  
@spec helix_rec_builder(last_value::value(),index::integer(),fields::[field()], conditions:: :array.array(), primes:: :array.array(), sect_zeros_numbers::[integer()],zeros_already_this_section::integer(),cycle::cycle(), size::size(),consts::[{integer(),value()}],map::%{},acc::[value()])::[value()]
  
  
  # az az eset (mintailesztéssel) amikor az index a következő constraints, és annka értéke 0
  def helix_rec_builder(last_value,i,[_field|rest_fields],conds,primes,sects_zeros,zeros_already,cycle,size,[{i,0}|rest_consts],map,acc) do
    #leteszem a nullást és megyek tovább,szekció marad ugyanaz
    helix_rec_builder(last_value,i+1,rest_fields,conds,primes,sects_zeros,zeros_already,cycle,size,rest_consts,map,[0|acc])
  end
  
  # az az eset (mintailesztéssel) amikor az index a következő constraints, és annka értéke NEM 0
  def helix_rec_builder(_last_value,i,[_field|rest_fields],conds,primes,[_this_sect_zeros|rest_sects_zeros],_zeros_already,cycle,size,[{i,const_value}|rest_consts],map,acc) do
    #leteszem az értéket, és átlépek a következő szekcióra
    helix_rec_builder(const_value,i+1,rest_fields,conds,primes,rest_sects_zeros,0,cycle,size,rest_consts,map,[const_value|acc])     
  end
  
  

  def helix_rec_builder(last_value,i,[{row,column}|rest_fields],conds,primes,[this_sect_zeros|_rest_sects_zeros]=sects_zeros,zeros_already,cycle,size,[{const_index,_const_value}|_rest_consts]=consts,map,acc) do
      
    value = rem(last_value,cycle) + 1 
    #IO.puts("ITER (i = #{i}), {#{row},#{column}}, val: #{value}, SECT_ZERO: #{this_sect_zeros}, rest: #{rest_sects_zeros}")
      
      
      next_value_is_possible =
        check_conditions({{row,column},value},conds,primes,size,cycle) and
          this_sect_zeros - zeros_already < const_index - i
      zero_is_possible = 
        check_conditions({{row,column},0},conds,primes,size,cycle) and
          this_sect_zeros > zeros_already
      #IO.puts("checking, next value: #{next_value_is_possible}, zero: #{zero_is_possible}")
    part_res_1 =
    if next_value_is_possible do
      this_prime = :array.get(value-1,primes)
      new_conds = 
        update_conditions(conds,[{2*(row-1),:mul,this_prime},{2*size+2*(column-1),:mul,this_prime}])
      helix_rec_builder(value,i+1,rest_fields,new_conds,primes,sects_zeros,zeros_already,cycle,size,consts,map,[value|acc])
    else
      []
    end
    part_res_2 =
    if zero_is_possible do
      new_conds = 
        update_conditions(conds,[{2*(row-1)+1,:add,1},{2*size+2*(column-1)+1,:add,1}])
      helix_rec_builder(last_value,i+1,rest_fields,new_conds,primes,sects_zeros,zeros_already+1,cycle,size,consts,map,[0|acc])
    else
      []
    end
    part_res_1 ++ part_res_2
    
  end
 
  def helix_rec_builder(_last_value,_i,[],_conds,_primes,_sects_zeros,_zeros_already,_cycle,size,_consts,map,acc) do
    #IO.puts("STOP (size = #{size}, i = #{i})")
    res = acc |> Enum.reverse()
    [result_announcer(res,size,map)]
    
  end 

  #megoldás felépító lapos listából
  @spec result_announcer(res::[value()],size::size(),map::%{})::[[value()]]
  def result_announcer(res,size,map) do
    for row <- 1..size do      
      for column <- 1..size do
        Enum.at(res,Map.get(map,{row,column})-1)
      end      
    end
  end
  
  @spec field_list_and_map_builder(n::size(),depth::integer(),result::[field()]):: {:array.array(),%{}}
  #épít egy tömböt a {row,column} értékekkel a tekeredő bejárás szerinti sorrendben
  def field_list_and_map_builder(0,_depth,result) do
    
    map = 
      Enum.with_index(result,1) 
      # a lista koordináta elemiből csinálok egy {koord,index} listát. Pl.: [{1,1},{1,2},...] -> [{{1,1},0},{{1,2},1},...]
      #1-estől kezdve
      |> Enum.into(%{}) #map-et csinálok az előző listából
    {result,map}
  end 
  def field_list_and_map_builder(1,depth,result), do: field_list_and_map_builder(0,depth,result++[{depth,depth}])

  def field_list_and_map_builder(n,depth,result) do
    top = for i <- 1..n do
      {depth,i+depth-1}
    end
    right=
    for i <- 2..n do
      {i+depth-1,n+depth-1}
    end
    bottom=
    for i <- n-1..1//-1 do
      {n+depth-1,i+depth-1}
    end
    left = 
    if n > 2 do
      for i <- n-1..2//-1 do
        {i+depth-1,depth}
      end
    else
      []
    end

    field_list_and_map_builder(n-2,depth+1,result++top++right++bottom++left)
  end
  
  
  #készít egy 2*(n+n)-es arrayt (mert sokszor módosítom, és fontos az indexelésen elérés a gyorsaság miatt)
  #ez tartalmazza, minden sorhoz, és minden oszlophoz 2 értéket: r, és f
  #             r:= egy integer, amelynek prím osztóji (p1*p2*...*pk) megfelelnek az értékeknek amelyek az adott sorban/oszloban vannak
  #             f:= egy integer, amennyi nullást helyeztünk már el az adott sorban/oszlopban
  
  @spec conditions_array_builder(n::size(),[field_value()],primes:: :array.array()):: :array.array()
  def conditions_array_builder(n,constraints,primes) do
    empty_arr = :array.from_list(
      for x <- 0 .. (2*(n+n)-1) do
        if rem(x,2) == 0 do
          1
        else
          0
        end
      end
    )
    
    modifiers = Enum.flat_map(constraints,fn {{row,col}, val} ->
      if val === 0 do
        [
          {2*(row-1)+1, :add, 1},
          {2*n + 2*(col-1)+1, :add, 1}
        ]
      else
        [
          {2*(row-1), :mul, :array.get(val-1, primes)},
          {2*n + 2*(col-1), :mul, :array.get(val-1, primes)}
        ]
      end
    end)
    update_conditions(empty_arr,modifiers)
    
  end


  #frissíti a conditions tömb értékeit, a megkapott változtatásokkal (amik vagy összeadás :add, vagy szorzás :mul)
  @spec update_conditions(array:: :array.array(),[{integer(),atom(),integer()}]):: :array.array()
  defp update_conditions(array,modifiers) do
    Enum.reduce(modifiers,array,fn {index,op,modif},acc ->
      case op do
        :add -> :array.set(index, :array.get(index,acc) + modif , acc)
        :mul -> :array.set(index, :array.get(index,acc) * modif , acc)
        
      
      end
    end)
  end

  #lecsekkol egy konrét cella, konkért érték esetén a conditions tömböt
  @spec check_conditions(field_value(),conditions:: :array.array(),primes:: :array.array(),size::size(),cycle::cycle())::boolean()
  def check_conditions({{row,column},value},conds,primes,size,cycle) do
      if value === 0 do
        :array.get(2*(row-1)+1,conds) < size - cycle and # adott sorban még elfér egy nullás
        :array.get(2*size + 2*(column-1)+1,conds) < size - cycle # az oszlopban is elfér nullás
      else
        rem(:array.get(2*(row-1),conds),:array.get(value-1,primes)) != 0 and  #adott sorban még nem szerepel value
        rem(:array.get(2*size + 2*(column-1),conds),:array.get(value-1,primes)) != 0 #oszlopban sem
      end      
  end
  

  #készít egy map-et, kulcsok 1,2,...,m, értékek különböző prímszámok (Eratoszthenész szitája)
  @spec prime_array_builder(m::cycle()):: :array.array()
  def prime_array_builder(m) do
    
    limit = 
      if m <= 10 do
        30
      else 
        trunc(m*:math.log(m)+10000)  #matematikaliag nem helyes de m pár ezres nagyságáig jó 
      end
    :array.from_list(Enum.take(Enum.reverse(sieve(Enum.to_list(2..limit),[])),m))
  end

  #szita metódus
  defp sieve([],result), do: result
  #az x mindig prím, mert minden prím x-nél kiveszem az összes többszörösét a hátralévő listából
  defp sieve([x|xs],result) do
    sieve(Enum.reject(xs, fn y -> rem(y, x) == 0 end), [x | result])
  end
  

  

  

end


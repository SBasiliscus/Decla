defmodule Nhf1 do
  @moduledoc """
  Number Spiral
  @author "Szabó András <andras.szabo.sb@gmail.com>"
  @date   "2025-10-25"
  ...
  """
  @type size()  :: integer() # size of the board (0 < n)
  @type cycle() :: integer() # cycle length (0 < m <= n)
  @type value() :: integer() # value of the field (0 < v <= m)
  
  @type row()   :: integer()       # row number (from 1 to n)
  @type col()   :: integer()       # column number (from 1 to n)
  @type field() :: {row(), col()}  # field coordinates

  @type field_value() :: {field(), value()}                 # field and its value
  @type puzzle_desc() :: {size(), cycle(), [field_value()]} # puzzle description

  @type retval()    :: integer()    # result field value (0 <= rv <= m)
  @type solution()  :: [[retval()]] # a solution
  @type solutions() :: [solution()] # all solutions

  
  @spec helix(sd::puzzle_desc()) :: ss::solutions()
  # ss is the list of all solutions for the puzzle given by the puzzle description sd
  def helix({size,cycle,fields}) do 
    
    # build the field_list, which is a list of {row, column} values,
    # giving the row and column values in the order of a spiral traversal
    # and a map, field ({row, column}) => index in the flattened order  
    {field_list,field_to_index_map} = field_list_and_map_builder(size,1,[])
    
    # build an array of length m containing prime numbers
    primes = prime_array_builder(cycle)
        
    # build the conditions array, from which we can read (method described in the function doc):
    #  - values present in every row and every column
    #  - number of zeros present in every row and every column
    conditions = conditions_array_builder(size,fields,primes)        

    # convert the constraints from coordinate-based to index-based, and sort them accordingly 
    const_with_index_sorted =
      fields
      |> Enum.map(fn {{row, col}, value} ->
        {Map.get(field_to_index_map, {row, col}), value}
      end)
      |> Enum.sort_by(fn {indx, _val} -> indx end)

    # count the zero constraints:
    zero_consts_counts = Enum.count(const_with_index_sorted, fn {_, v} -> v === 0 end)
    
    # collect the non-zero constraints from the constraints, 
    # and decrease their indices by the number of zero constraints that would have preceded them
    constraints_without_zeros = 
      const_with_index_sorted
    # iterate through the sorted constraints with a two-element accumulator, 
    # storing non-zero constraints in one, and the current shift amount in the other
      |> Enum.reduce({[],0}, fn {index,val},{acc,shift} ->
        if val === 0 do
          {acc, shift+1}
        else
          {[{index-shift,val}|acc],shift}
        end
              
        end)
      |> elem(0)
      |>Enum.reverse()

    # calculate the minimum and maximum number of zeros for each section 
    # (more precisely, the max value of x for which the section can fit min+x*m zeros)
    minmaxes = min_max_distribution(0,cycle,cycle,size*size-zero_consts_counts,constraints_without_zeros)

    # iterate through the ways to distribute the zeros among the sections
    poss_distributions = 
    possible_zeros_distribution_recursive(
          Enum.map(minmaxes,fn {_a,b} -> b end), # max zeros that can be placed in sections (*cycle)
          div(size*size-size*cycle-zero_consts_counts-Enum.reduce(minmaxes,0,fn {a,_}, acc -> acc + a end),cycle), #
          cycle,
          Enum.map(minmaxes,fn {a,_b} -> a end)) # min zeros to be placed in sections
    
    # return an empty list in case it's unsolvable
      if poss_distributions == [-1] do
        []
      else
          # pass the list of lists of possible 0 distributions to the collector method, but collect them flattened
      Enum.flat_map(poss_distributions,
        fn one_zero_dist -> 
          # examine the possible solutions for a specific zero distribution

          helix_rec_builder(cycle,1,field_list,conditions,primes,one_zero_dist,0,cycle,size,const_with_index_sorted++[{size*size+1,1}],field_to_index_map,[])

        end
        )
          
    end
  end
  
  @spec possible_zeros_distribution_recursive(list::[integer()],free_zeros::integer(),cycle::cycle(),tied::[integer()])::[[integer()]]
  # helper method that receives in a list how many times m-zeros can maximally fit in each section
  # and a number showing how many times m zeros have free space to move overall (i.e., not fixedly forced into one section)
  # returns the different valid 0 distributions
  # free_zeros: there are in total free_zeros*cycle freely movable zeros
  # tied: list giving the minimum number of zeros to be placed in the different sections
  defp possible_zeros_distribution_recursive([akt|[_sm|_sms]=rest],free_zeros,cycle,[akt_tied|rest_tied]) do 
    if Enum.sum([akt|rest])<free_zeros or Enum.any?([akt_tied|rest_tied]++[akt|rest], fn x -> x < 0 end) do
      # the case when zeros cannot be distributed
      #  either because there aren't enough
      #  or because a negative number of minimum zeros is needed in a section (i.e., not enough cells to reach from the last element before the section in ascending order to the first element after the section)
      [-1]
    else
      starting_x = max(0, free_zeros - Enum.sum(rest))
      ending_x = min(akt, free_zeros)
      if ending_x>=starting_x do
        for x <- starting_x..ending_x,
          rest_made <- possible_zeros_distribution_recursive(rest,free_zeros-x,cycle,rest_tied) do
          [x*cycle+akt_tied|rest_made]
        end
      else
        []
      end
    end
  end  
  defp possible_zeros_distribution_recursive([_akt|[]],free_zeros,cycle,[akt_tied|_r]), do: [[free_zeros*cycle+akt_tied]]

  
  @spec min_max_distribution(ij::integer(),j::value(),m::cycle(),len::size(),constraints::[{integer(),value()}])::{min::integer(),max::integer()}
  # returns the minimum zero and maximum number pair {min,max} for every section
  # min = least compulsory zeros in the section
  # max = max(x) : min+m*x zeros can be placed in the section
  defp min_max_distribution(ij,j,m,len,[{ik,k}|constraints]) do
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
  
  defp min_max_distribution(ij,j,m,len,[]) do
    sect_len = len+1-ij-1
    [
      
        {
          sect_len  -  ( (m-j) + m*div(sect_len-(m-j),m) )   ,
          div(sect_len-(m-j),m)
        }
    ]
  end
  
  

  
  
  @spec helix_rec_builder(last_value::value(),index::integer(),fields::[field()], conditions:: :array.array(), primes:: :array.array(), sect_zeros_numbers::[integer()],zeros_already_this_section::integer(),cycle::cycle(), size::size(),consts::[{integer(),value()}],map::%{},acc::[value()])::[value()]
  
  
  # the case (via pattern matching) where the index is the next constraint, and its value is 0
  defp helix_rec_builder(last_value,i,[_field|rest_fields],conds,primes,sects_zeros,zeros_already,cycle,size,[{i,0}|rest_consts],map,acc) do
    # put down the zero and move on, section remains the same
    helix_rec_builder(last_value,i+1,rest_fields,conds,primes,sects_zeros,zeros_already,cycle,size,rest_consts,map,[0|acc])
  end
  
  # the case (via pattern matching) where the index is the next constraint, and its value is NOT 0
  defp helix_rec_builder(_last_value,i,[_field|rest_fields],conds,primes,[_this_sect_zeros|rest_sects_zeros],_zeros_already,cycle,size,[{i,const_value}|rest_consts],map,acc) do
    # put down the value and step to the next section
    helix_rec_builder(const_value,i+1,rest_fields,conds,primes,rest_sects_zeros,0,cycle,size,rest_consts,map,[const_value|acc])   

  end
  
  

  defp helix_rec_builder(last_value,i,[{row,column}|rest_fields],conds,primes,[this_sect_zeros|_rest_sects_zeros]=sects_zeros,zeros_already,cycle,size,[{const_index,const_value}|_rest_consts]=consts,map,acc) do
      
    value = rem(last_value,cycle) + 1 
      
    
    {next_non_zero_const_index,_} = 

      if const_value === 0 do
        Enum.find(consts,fn {_cnst_index,cnst_value} -> cnst_value != 0 end)
      else
        {const_index,0}
      end
      
      next_value_is_possible =
        check_conditions({{row,column},value},conds,primes,size,cycle) and
          this_sect_zeros - zeros_already < next_non_zero_const_index - i
      zero_is_possible = 
        check_conditions({{row,column},0},conds,primes,size,cycle) and
          this_sect_zeros > zeros_already
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
 
  defp helix_rec_builder(_last_value,_i,[],_conds,_primes,_sects_zeros,_zeros_already,_cycle,size,_consts,map,acc) do
    res = acc |> Enum.reverse()
    [result_announcer(res,size,map)]
    
  end 

  # building solution from a flat list
  @spec result_announcer(res::[value()],size::size(),map::%{})::[[value()]]
  defp result_announcer(res,size,map) do
    for row <- 1..size do      
      for column <- 1..size do
        Enum.at(res,Map.get(map,{row,column})-1)
      end      
    end
  end
  
  @spec field_list_and_map_builder(n::size(),depth::integer(),result::[field()]):: {:array.array(),%{}}
  # builds an array with {row,column} values in the order of a spiral traversal
  defp field_list_and_map_builder(0,_depth,result) do
    
    map = 
      Enum.with_index(result,1) 
      # convert the coordinate elements of the list into a {coord, index} list. Ex: [{1,1},{1,2},...] -> [{{1,1},0},{{1,2},1},...]
      # starting from 1
      |> Enum.into(%{}) # make a map from the previous list
    {result,map}
  end 
  defp field_list_and_map_builder(1,depth,result), do: field_list_and_map_builder(0,depth,result++[{depth,depth}])

  defp field_list_and_map_builder(n,depth,result) do
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
  
  
  # creates a 2*(n+n) array (because I modify it often, and index access is important for speed)
  # this contains 2 values for every row and every column: r and f
  #             r := an integer whose prime divisors (p1*p2*...*pk) correspond to the values present in the given row/column
  #             f := an integer, the number of zeros already placed in the given row/column  
  @spec conditions_array_builder(n::size(),[field_value()],primes:: :array.array()):: :array.array()
  defp conditions_array_builder(n,constraints,primes) do
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


  # updates the values of the conditions array with the received modifiers (which are either addition :add or multiplication :mul)
  @spec update_conditions(array:: :array.array(),[{integer(),atom(),integer()}]):: :array.array()
  defp update_conditions(array,modifiers) do
    Enum.reduce(modifiers,array,fn {index,op,modif},acc ->
      case op do
        :add -> :array.set(index, :array.get(index,acc) + modif , acc)
        :mul -> :array.set(index, :array.get(index,acc) * modif , acc)
        
      
      end
    end)
  end

  # checks the conditions array for a specific cell and specific value
  @spec check_conditions(field_value(),conditions:: :array.array(),primes:: :array.array(),size::size(),cycle::cycle())::boolean()
  defp check_conditions({{row,column},value},conds,primes,size,cycle) do
      if value === 0 do
        :array.get(2*(row-1)+1,conds) < size - cycle and # a zero still fits in the given row
        :array.get(2*size + 2*(column-1)+1,conds) < size - cycle # a zero still fits in the column
      else
        rem(:array.get(2*(row-1),conds),:array.get(value-1,primes)) != 0 and  # value is not yet in the given row
        rem(:array.get(2*size + 2*(column-1),conds),:array.get(value-1,primes)) != 0 # nor in the column
        
      end      
  end
  

  # creates an array, keys 1,2,...,m, values are different prime numbers (Sieve of Eratosthenes)
  @spec prime_array_builder(m::cycle()):: :array.array()
  defp prime_array_builder(m) do
    
    limit = 
      if m <= 10 do
        30
      else 
        trunc(m*:math.log(m)+10000)  # mathematically incorrect but fine up to an m of a few thousand 
      end
    :array.from_list(Enum.take(Enum.reverse(sieve(Enum.to_list(2..limit),[])),m))
  end

  # sieve method
  defp sieve([],result), do: result
  # x is always prime, because for every prime x I remove all its multiples from the remaining list
  defp sieve([x|xs],result) do
    sieve(Enum.reject(xs, fn y -> rem(y, x) == 0 end), [x | result])
  end
  

  

  

end

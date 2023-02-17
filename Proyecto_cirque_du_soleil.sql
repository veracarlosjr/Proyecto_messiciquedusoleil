use messi_10;

-- vista#1 - Cantidad de tickets comprados y la cantidad de clientes segun el metodo de pago.
create or replace view vw_clientesytickets_por_metodopago as
(select t.metodo_pago, count(o.id_cliente) as cantidad_clientes, sum(o.cantidad_tickets ) as cantidad_tickets
from tipo_pago as t
	inner join orden as o
	on t.id_pago = o.id_pago
group by t.metodo_pago
order by cantidad_tickets desc
);

-- vista#2 - Top 5 de los dia de funcion que mas ha vendido del evento
create or replace view vw_top5_eventosmasvendidos as
(select e.fecha_show as fecha, t.costo_ticket as Recaudado
from evento as e
	inner join ticket as t
	on e.id_evento = t.id_evento
group by fecha
order by Recaudado desc
limit 5
);

-- vista#3 - Cantidad recaudada y cantidad de tickets vendidos por tribuna. 
create or replace view vw_tickesymontorecaudado_portribuna as
(select tr.tribuna, sum(t.costo_ticket) as recaudado , sum(o.cantidad_tickets) as tickets_vendidos
from tribuna as tr
	inner join ticket as t
    on tr.id_tribuna = t.id_tribuna
    inner join orden as o
    on t.id_orden = o.id_orden
group by tr.tribuna
);

-- vista#4 - Cantidad de tickets vendidos por promociones
create or replace view vw_ticketsvenvidos_conpromociones as 
(select t.tipo_precio as promocion, sum(o.cantidad_tickets) as tickets_vendidos
from tipo_pago as t
	inner join orden as o
    on t.id_pago = o.id_pago
where t.tipo_precio <> 'REG' 
group by t.tipo_precio
order by sum(o.cantidad_tickets) desc
);

-- vista#5 - Region en la que mas clientes han comprado usando mercadopago como metodo de pago.
create or replace view vw_tickets_porpaisyregion_conmercadopago as
(select c.region, sum(o.cantidad_tickets) as cantidad_tickets
from cliente as c
	inner join	orden as o
    on c.id_cliente = o.id_cliente
    inner join tipo_pago as t
    on o.id_pago = t.id_pago 
where metodo_pago = 'MercadoPago'
group by c.region
order by sum(o.cantidad_tickets) desc
);

-- FUNCIONES

-- calcula la cantidad de clientes segun la region que seleccione. 
drop function if exists fn_clientesregion ;
delimiter //
create function fn_clientesregion(p_region varchar(50))
returns int
deterministic
begin
	declare num_clientes int;
    
    select count(*) into num_clientes
    from cliente
    where region = p_region;
    
    
    return num_clientes ;
end//
delimiter ;

select fn_clientesregion('buenos aires') as cant_clientes;



-- calcula la cantidad de tickets vendidos segun la region que seleccione. 
drop function if exists fn_ticketsregion ;
delimiter //
create function fn_ticketsregion(p_region varchar(50))
returns int
deterministic
begin

	declare num_tickets int;
    
    select sum(o.cantidad_tickets) into num_tickets
    from orden as o
		inner join cliente as c
        on o.id_cliente = c.id_cliente
    where c.region = p_region;
    
    return num_tickets ;
    
end//
delimiter ;

select fn_ticketsregion('buenos aires') as cant_tickets;

-- PROCEDIMIENTO

-- Procedimiento 1
-- Informacion sobre la cantidad de tickets vendido y el dinero recaudad por funcion. Se puede realizar filtrados por: funcion, recaudado, tickets vendidos
drop function  if exists fn_p_mensaje_error ;
delimiter //
create function fn_p_mensaje_error ( p_mensaje_error varchar(255) )
returns varchar(255)
deterministic
begin
   declare v_mensaje varchar(255);

   if p_mensaje_error  = ''   THEN
      set v_mensaje = 'Escriba correctamente el parametro';
   else
      set v_mensaje = 'OK';
   end if;

   return v_mensaje;
end //
delimiter ;

select fn_p_mensaje_error('A') ;


 drop procedure  if exists SP_ordenar ;
 
 delimiter //
create procedure SP_ordenar (inout p_funcion varchar(50),
							 inout p_asc_desc varchar(50),
                             inout p_mensaje varchar(255))
begin

declare v_mensaje  varchar(255) ;
  select  fn_p_mensaje_error(p_funcion)  into  @p_mensaje ;  
  
  if @p_mensaje = 'OK' THEN
  set @t1 =  concat('select e.fecha_show as funcion, sum(t.costo_ticket) as recaudado,
							sum(o.cantidad_tickets) as tickets_vendidos
							from evento as e
							inner join ticket as t
							on e.id_evento = t.id_evento
							inner join orden as o
							on t.id_orden = o.id_orden
							group by funcion
                            order by ',' ',p_funcion,' ',p_asc_desc);
  prepare param_stmt from @t1   ;
  execute param_stmt;  
  deallocate prepare param_stmt;
  else set v_mensaje = @p_mensaje ;
  end if ; 
end //
delimiter ;

set @p_funcion = 'funcion'; 
set @p_asc_desc = 'ASC'; 

call SP_ordenar (@p_funcion ,@p_asc_desc, @p_mensaje);

-- Procedimineto 2 
-- Insertar informacion de nuevos clientes

drop procedure if exists SP_Insert_nuevocliente;

delimiter //
create procedure SP_Insert_nuevocliente   (inout P_ciudad varchar (50),
										   inout P_region varchar (50),
                                           inout P_pais varchar(50))
begin 
 insert into cliente (ciudad,region,pais)
 values (P_ciudad,P_region,P_pais);

end //
delimiter ;
set @P_ciudad = 'Merida';
set @P_region = 'Los Andes';
set @P_pais = 'Venezuela';

call SP_Insert_nuevocliente (@P_ciudad,@P_region,@P_pais);
select * from cliente order by pais desc;

-- TRIGGERS

-- TRIGGERS 1 En la siguiente tabla de auditoria quedara registrado cualquier modificacion que sufra la tabla de clientes, y la insercion de nuevos compradores.


drop table if exists log_auditoria;
create table if not exists log_auditoria
(
id_log int auto_increment ,
camponuevo_campoanterior varchar (3200) ,
nombre_de_accion varchar (50) ,
nombre_tabla varchar (50) ,
ciudad varchar (50) , 
region varchar (50) ,
pais varchar (50) ,
usuario varchar (100) ,
fecha_upd_ins_del date ,
hora_upd_ins_del time,
primary key (id_log)
)
;

drop trigger if exists tgr_nuevo_cliente10 ;
delimiter //
create trigger trg_nuevo_cliente10 
after insert
on messi_10.cliente 
for each row
begin
	
    insert into log_auditoria (camponuevo_campoanterior , nombre_de_accion , nombre_tabla , ciudad , region , pais , usuario , fecha_upd_ins_del , hora_upd_ins_del)
    values ( '' , 'insert' , 'cliente' , NEW.ciudad , NEW.region , NEW.pais , current_user() , now() , now());
     
end//
delimiter ; 


drop trigger if exists tgr_modificado_cliente ;
delimiter //
create trigger tgr_modificado_cliente before update 
on messi_10.cliente 
for each row
begin
	
    insert into log_auditoria (camponuevo_campoanterior , nombre_de_accion , nombre_tabla , ciudad , region , pais , usuario , fecha_upd_ins_del , hora_upd_ins_del)
    values ( concat('campo_anterior :', old.pais , old.ciudad , old.region , ' ' , 'campo_nuevo :' , new.pais , new.ciudad , new.region ) , 'update' , 'cliente' , NEW.ciudad , New.region , NEW.pais , current_user() , now() , now());
    
end//
delimiter ;


 -- Ejemplos:
 
update messi_10.cliente set pais = 'brasil' , ciudad = 'brasilia' , region =  'Federal' where id_cliente = 39 ;

 insert into messi_10.cliente (ciudad,region,pais)
 values ('tachira','los andes','venezuela');
 
 
select * from log_auditoria ;

--  TRIGGERS 2 En la siguiente tabla de auditoria quedara registrado cualquier modificacion que sufra las fechas de eventos , y la insercion de nuevos compradores.


drop table if exists log_auditoria_2;
create table if not exists log_auditoria_2
(
id_log int auto_increment ,
nombre_de_accion varchar (50) ,
nombre_tabla varchar (50) ,
campo_anterior varchar (3200) ,
tipo_evento varchar (50) , 
fecha_show date ,
hora_show time ,
usuario varchar (100) ,
fecha_upd_ins_del date ,
hora_upd_ins_del time,
primary key (id_log)
)
;

drop trigger if exists tgr_evento_adicional ;
delimiter //
create trigger tgr_evento_adicional after insert
on messi_10.evento
for each row
begin
	
    insert into log_auditoria_2 (nombre_de_accion , nombre_tabla , campo_anterior ,
    tipo_evento , fecha_show , hora_show , usuario , fecha_upd_ins_del , hora_upd_ins_del)
    values ( 'insert' , 'evento' , '' , New.tipo_evento , NEW.fecha_show , NEW.hora_show ,
    current_user() , now() , now());
  
end//
delimiter ; 

drop trigger if exists tgr_eliminar_evento ;
delimiter //
create trigger tgr_eliminar_evento before delete
on messi_10.evento
for each row
begin
	
    insert into log_auditoria_2 (nombre_de_accion , nombre_tabla , campo_anterior ,
    tipo_evento , fecha_show , hora_show , usuario , fecha_upd_ins_del , hora_upd_ins_del)
    values ( 'delete' , 'evento' , '' , old.tipo_evento , old.fecha_show , old.hora_show ,
    current_user() , now() , now());
  
end//
delimiter ; 

drop trigger if exists tgr_modificado_sector ;
delimiter //
create trigger tgr_modificado_sector before update 
on messi_10.evento 
for each row
begin
	
    insert into log_auditoria_2 (nombre_de_accion , nombre_tabla , campo_anterior ,
    tipo_evento , fecha_show , hora_show , usuario , fecha_upd_ins_del , hora_upd_ins_del)
    values ( 'update' , 'evento' , concat(old.tipo_evento ,'//', old.fecha_show ,'//', old.hora_show)
    , New.tipo_evento , new.fecha_show , new.hora_show , current_user() , now() , now());
    
end//
delimiter ;

insert into messi_10.evento (tipo_evento,fecha_show,hora_show) values ('Sector 3','2023-04-30','22:00:00'); 

delete from messi_10.evento where id_evento = 108 ;

update messi_10.evento set tipo_evento = 'Sector 5' where id_evento = 100 ;

select * from log_auditoria_2;


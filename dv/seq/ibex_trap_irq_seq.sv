class ibex_trap_fixed_irq_seq extends uvm_sequence #(irq_seq_item);

  bit        irq_software;
  bit        irq_timer;
  bit        irq_external;
  bit [14:0] irq_fast;
  bit        irq_nm;

  `uvm_object_utils(ibex_trap_fixed_irq_seq)

  function new(string name = "ibex_trap_fixed_irq_seq");
    super.new(name);
  endfunction

  virtual task body();
    irq_seq_item req;
    req = irq_seq_item::type_id::create("req");
    start_item(req);
    req.irq_software   = irq_software;
    req.irq_timer      = irq_timer;
    req.irq_external   = irq_external;
    req.irq_fast       = irq_fast;
    req.irq_nm         = irq_nm;
    req.num_of_interrupt =
        $countones({irq_software, irq_timer, irq_external, irq_fast, irq_nm});
    finish_item(req);
    get_response(req);
  endtask

  function void set_irq_id(int id);
    irq_software = 1'b0;
    irq_timer    = 1'b0;
    irq_external = 1'b0;
    irq_fast     = '0;
    irq_nm       = 1'b0;

    case (id)
      3:  irq_software = 1'b1;
      7:  irq_timer    = 1'b1;
      11: irq_external = 1'b1;
      31: irq_nm       = 1'b1;
      default: begin
        if (id inside {[16:30]}) irq_fast[id-16] = 1'b1;
        else `uvm_fatal("TRAP_IRQ_SEQ", $sformatf("Unsupported IRQ id %0d", id))
      end
    endcase
  endfunction

endclass : ibex_trap_fixed_irq_seq

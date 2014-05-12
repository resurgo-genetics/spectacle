class ModelsController < ApplicationController
  def overview
    query = params.slice(:id, :subclass_name)
    base_query_params = params.slice(:id, :subclass_name, :analysis_project_id, :status)

    @models = Model.where(query)
    unless params[:analysis_project_id].blank?
      @models = @models.joins(:analysis_project_model_bridges).where(analysis_project_model_bridge: { analysis_project_id: params[:analysis_project_id] })
    end
    unless params[:status].blank?
      if params[:analysis_project_id].blank? and params[:id].blank?
        return render text: "Query by status requires additional filtering.", status: 400
      end

      raise ActiveRecord::RecordNotFound unless @models.any?
      model_ids = @models.map { |m| m.genome_model_id }
      statuses = ModelStatusQuery.new(model_ids).execute
      @models = @models.select { |m| statuses.find { |(id,status)| id = m.genome_model_id && status = params[:status] } }
    end

    raise ActiveRecord::RecordNotFound unless @models.any?

    model_ids = @models.map { |model| model.id }
    statuses = ModelStatusQuery.new(model_ids).execute
    models_by_type = @models.group_by(&:subclass_name)

    @model_type_chart      = ModelTypeChart.new(models_by_type, base_query_params, view_context)
    @model_status_chart    = ModelStatusChart.new(statuses, base_query_params, view_context)

    models_with_status = statuses.each_with_object(@models.each_with_object({}) do |item, hash|
      hash[item.id] = { model: item }
    end) do |status, hash|
      hash[status['model_id']][:status] = status['status']
    end

    @model_status_table    = ModelStatusTable.new(models_with_status, view_context())
  end

  def status
    @model = Model.with_statuses_scope.where(id: params[:id]).first!
    builds = @model.builds

    @build_status_chart    = BuildStatusChart.new(builds)
    @build_status_table    = BuildStatusTable.new(builds)
  end
end

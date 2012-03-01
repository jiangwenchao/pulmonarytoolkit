classdef TDAirways < TDPlugin
    % TDAirways. Plugin for segmenting the pulmonary airways from CT data
    %
    %     This is a plugin for the Pulmonary Toolkit. Plugins can be run using 
    %     the gui, or through the interfaces provided by the Pulmonary Toolkit.
    %     See TDPlugin.m for more information on how to run plugins.
    %
    %     Plugins should not be run directly from your code.
    %
    %     TDAirways calls the TDTopOfTrachea plugin to find the trachea
    %     location, and then runs the library routine
    %     TDAirwayRegionGrowingWithExplosionControl to obtain the
    %     airway segmentation. The results are stored in a heirarchical tree
    %     structure.
    %
    %     The output image generated by GenerateImageFromResults creates a
    %     colour-coded segmentation image with true airway points shown as blue
    %     and explosion points shown in red.
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %    
    
    properties
        ButtonText = 'Airways'
        ToolTip = 'Shows a segmentation of the airways illustrating deleted points'
        Category = 'Airways'

        AllowResultsToBeCached = true
        AlwaysRunPlugin = false
        PluginType = 'ReplaceOverlay'
        HidePluginInDisplay = false
        FlattenPreviewImage = true
        TDPTKVersion = '1'
        ButtonWidth = 6
        ButtonHeight = 2
        GeneratePreview = true
    end
    
    methods (Static)
        function results = RunPlugin(dataset, reporting)
            trachea_results = dataset.GetResult('TDTopOfTrachea');
            
            % Fetch the start point in global coordinates
            start_point = trachea_results.top_of_trachea;
            
            % We use results from the trachea finding to remove holes in the
            % trachea, which can otherwise cause early branching of the airway
            % algorithm            
            threshold = dataset.GetResult('TDLungROI');
            
            % Convert the start point to local coordinates relative to the ROI
            start_point = threshold.GlobalToLocalCoordinates(start_point);
            
            threshold = TDThresholdAirway(threshold);
            threshold_raw = threshold.RawImage;
            threshold_raw = threshold_raw > 0;
            trachea_voxels_global = trachea_results.trachea_voxels;
            trachea_voxels_local = threshold.GlobalToLocalIndices(trachea_voxels_global);
            threshold_raw(trachea_voxels_local) = true;

            threshold.ChangeRawImage(threshold_raw);
            
            results = TDAirwayRegionGrowingWithExplosionControl(threshold, start_point, reporting);
        end
        
        function results = GenerateImageFromResults(airway_results, image_templates, ~)
            template_image = image_templates.GetTemplateImage(TDContext.LungROI);
            
            image_size = airway_results.image_size;
            
            airway_image = zeros(image_size, 'uint8');
            
            airway_image(airway_results.explosion_points) = 3;
            

            airway_tree = airway_results.airway_tree;
            segments_to_do = airway_tree;
            while ~isempty(segments_to_do)
                segment = segments_to_do(end);
                segments_to_do(end) = [];
                voxels = segment.GetAllAirwayPoints;
                airway_image(voxels) = 1;
                segments_to_do = [segments_to_do, segment.Children];
            end
                        
            results = template_image;
            results.ChangeRawImage(airway_image);
            results.ImageType = TDImageType.Colormap;
       end
    end
end